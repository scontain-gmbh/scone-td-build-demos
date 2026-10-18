#!/usr/bin/env python3
"""Anonymous, read-only OCI digest resolver (no credential files are consulted).

Usage: resolve_digests.py OUTDIR REF...
Writes OUTDIR/digests.json and, for each resolved amd64 manifest, the exact
config blob as OUTDIR/<safe-name>.config.json.
"""
import datetime, hashlib, json, sys, urllib.error, urllib.parse, urllib.request

ACCEPT = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])
INDEX_TYPES = {"application/vnd.oci.image.index.v1+json",
               "application/vnd.docker.distribution.manifest.list.v2+json"}

def parse(ref):
    name, tag = ref.rsplit(":", 1)
    first = name.split("/", 1)[0]
    if "." in first or ":" in first:
        host, repo = name.split("/", 1)
    else:
        host, repo = "registry-1.docker.io", name if "/" in name else "library/" + name
    return host, repo, tag

class NoRedirectAuth(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new is not None:
            new.remove_header("Authorization")  # never forward the token to a CDN
        return new

OPENER = urllib.request.build_opener(NoRedirectAuth())

def token(host, repo):
    try:
        OPENER.open(urllib.request.Request(f"https://{host}/v2/"), timeout=30)
        return None
    except urllib.error.HTTPError as e:
        hdr = e.headers.get("WWW-Authenticate", "")
    if not hdr.lower().startswith("bearer"):
        return None
    params = dict(p.split("=", 1) for p in hdr[7:].split(","))
    params = {k.strip(): v.strip().strip('"') for k, v in params.items()}
    q = {"service": params.get("service", ""), "scope": f"repository:{repo}:pull"}
    url = params["realm"] + "?" + urllib.parse.urlencode(q)
    with OPENER.open(url, timeout=30) as r:
        body = json.load(r)
    return body.get("token") or body.get("access_token")

def get(host, repo, path, tok, accept=None):
    req = urllib.request.Request(f"https://{host}/v2/{repo}/{path}")
    if tok:
        req.add_header("Authorization", "Bearer " + tok)
    if accept:
        req.add_header("Accept", accept)
    with OPENER.open(req, timeout=60) as r:
        return r.read(), r.headers.get("Content-Type", "").split(";")[0], r.headers.get("Docker-Content-Digest")

def sha(b):
    return "sha256:" + hashlib.sha256(b).hexdigest()

def resolve(ref, outdir):
    rec = {"reference": ref, "resolved_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")}
    host, repo, tag = parse(ref)
    rec["registry"], rec["repository"], rec["tag"] = host, repo, tag
    try:
        tok = token(host, repo)
        body, ctype, hdr_digest = get(host, repo, f"manifests/{tag}", tok, ACCEPT)
    except urllib.error.HTTPError as e:
        rec["error"] = f"HTTP {e.code}: {e.read()[:300].decode(errors='replace')}"
        return rec
    except Exception as e:  # noqa: BLE001
        rec["error"] = f"{type(e).__name__}: {e}"
        return rec
    top = sha(body)
    if hdr_digest and hdr_digest != top:
        rec["error"] = f"digest header {hdr_digest} != computed {top}"
        return rec
    rec["top_media_type"] = ctype or json.loads(body).get("mediaType")
    doc = json.loads(body)
    if rec["top_media_type"] in INDEX_TYPES or "manifests" in doc:
        rec["index_digest"] = top
        amd = [m for m in doc["manifests"] if m.get("platform", {}).get("os") == "linux"
               and m.get("platform", {}).get("architecture") == "amd64"
               and not m.get("platform", {}).get("variant")]
        rec["platforms"] = sorted({f"{m['platform']['os']}/{m['platform']['architecture']}" + (f"/{m['platform']['variant']}" if m['platform'].get('variant') else "")
                                   for m in doc["manifests"] if m.get("platform", {}).get("os") not in (None, "unknown")})
        if len(amd) != 1:
            rec["error"] = f"expected one linux/amd64 entry, found {len(amd)}"
            return rec
        mdig = amd[0]["digest"]
        body, ctype, _ = get(host, repo, f"manifests/{mdig}", tok, amd[0]["mediaType"])
        if sha(body) != mdig:
            rec["error"] = "amd64 manifest digest mismatch"
            return rec
        doc = json.loads(body)
    else:
        mdig = top
    rec["amd64_manifest_digest"] = mdig
    rec["amd64_manifest_media_type"] = doc.get("mediaType", ctype)
    cfg = doc["config"]
    blob, _, _ = get(host, repo, f"blobs/{cfg['digest']}", tok)
    if sha(blob) != cfg["digest"] or len(blob) != cfg["size"]:
        rec["error"] = "config blob mismatch"
        return rec
    safe = ref.replace("/", "_").replace(":", "_")
    open(f"{outdir}/{safe}.config.json", "wb").write(blob)
    c = json.loads(blob)
    rec["config"] = {"media_type": cfg["mediaType"], "size": cfg["size"], "digest": cfg["digest"],
                     "file": f"{safe}.config.json", "os": c.get("os"), "architecture": c.get("architecture"),
                     "Entrypoint": c.get("config", {}).get("Entrypoint"), "Cmd": c.get("config", {}).get("Cmd"),
                     "WorkingDir": c.get("config", {}).get("WorkingDir"), "User": c.get("config", {}).get("User")}
    rec["pinned"] = f"{host if host != 'registry-1.docker.io' else 'docker.io'}/{repo}@{mdig}"
    return rec

if __name__ == "__main__":
    outdir = sys.argv[1]
    out = [resolve(r, outdir) for r in sys.argv[2:]]
    json.dump(out, open(f"{outdir}/digests.json", "w"), indent=2)
    print(json.dumps(out, indent=2))
