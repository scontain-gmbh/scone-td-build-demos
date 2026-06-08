## Add `software-updates` demo

Adds a new example showing how to perform a confidential software update using `scone-td-build`. Two versions of a Python application are built and deployed as a Kubernetes Deployment. The demo shows that `API_PASSWORD` is preserved across the update because CAS generates it on first session creation via a `SconeSecret` — nobody sets it, and CAS auto-migrates the secret when the session is updated under the same namespace.

### What's included

- `print_env1.py` / `print_env2.py` — minimal Python scripts that print `API_USER` and an `md5` checksum of `API_PASSWORD`, running in a loop
- `Dockerfile` — builds either version via `--build-arg VERSION=1|2`
- `k8s/manifest.v1.template.yaml` / `k8s/manifest.v2.template.yaml` — Kubernetes `Deployment` templates for each version; `API_PASSWORD` is injected via `secretKeyRef` from a `SconeSecret`
- `k8s/scone-secret.yaml` — `SconeSecret` CR that tells CAS to generate `API_PASSWORD`
- `scone.v1.template.yaml` / `scone.v2.template.yaml` — SCONE `Register` + `Apply` CRD templates; both share the same session namespace so v2 updates the existing CAS session in-place
- `environment-variables.md` — tplenv variable definitions (`API_USER`, image names, namespace, etc.; no `API_PASSWORD` — CAS generates it)
- `registry.credentials.md` — registry credential definitions (SIGNER, REGISTRY_USER, REGISTRY_TOKEN kept out of `Values.yaml`)
- `Values.yaml` — default values following the same structure as other demos (`NAMESPACE: default`, no secrets stored)
- Entry added to root `README.md`
- `scripts/software-updates.sh` and `docs/software-updates.sh` generated from the README
- `scripts/prepare-example-ci.sh` updated to include `software-updates/Values.yaml`

### Demo flow

1. Build and push native images for both versions
2. **Part 1 — SCONE v1**: build the confidential image, create the CAS session (CAS generates `API_PASSWORD`), deploy the Deployment and verify
3. **Part 2 — Software update**: build the confidential v2 image (updates the existing CAS session), redeploy via rolling update, and verify the `API_PASSWORD` checksum matches v1

### Key design decisions

- Uses Kubernetes `Deployment` (not `Job`) since the app runs in a continuous loop — v2 replaces v1 via a rolling update
- `API_PASSWORD` is CAS-generated via `SconeSecret`; it is injected into the pod through `secretKeyRef` and never appears in any manifest or Kubernetes Secret visible to a cluster administrator
- Both SCONE configs share `metadata.name: software-updates-demo` so the v2 build updates the existing session rather than creating a new one, and CAS auto-migrates the generated secret to the new session
