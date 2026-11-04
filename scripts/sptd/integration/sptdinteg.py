"""Shared helpers for the sptd integration scripts (docs/sptd-integration.md). NON_RELEASE.

Standard library only, so the scripts and their tests run on a laptop without PyYAML,
jsonschema, a cluster or any key.

- a small JSON Schema interpreter for the subset the pinned schemas in this directory use
  (type, const, enum, pattern, required, properties, additionalProperties, items,
  minItems, maxItems, minLength, maxLength, minimum, uniqueItems, $ref to #/$defs/...)
- the canonical JSON encoding and the artifact-set hash
- loading the demo catalog (demos.json) and the landed-image facts
"""
import hashlib
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
CATALOG = os.path.join(HERE, "demos.json")
MANIFEST_SCHEMA = os.path.join(HERE, "artifact-manifest.schema.json")
FACTS_SCHEMA = os.path.join(HERE, "landed-image-facts.schema.json")

SHA256 = re.compile(r"^sha256:[0-9a-f]{64}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
ZERO_DIGEST = "sha256:" + "0" * 64


class Invalid(Exception):
    """A document does not match its schema or a cross-check failed."""


def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def canonical(value):
    """Canonical JSON bytes: sorted keys, no whitespace, UTF-8."""
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


def file_sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def artifact_set_sha256(manifest):
    """The artifact-set hash: SHA-256 of the canonical manifest without its own hash field."""
    body = {key: value for key, value in manifest.items() if key != "artifactSetSha256"}
    return sha256_bytes(canonical(body))


# --------------------------------------------------------------------------------------
# JSON Schema subset


_TYPES = {
    "object": lambda v: isinstance(v, dict),
    "array": lambda v: isinstance(v, list),
    "string": lambda v: isinstance(v, str),
    "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "boolean": lambda v: isinstance(v, bool),
    "null": lambda v: v is None,
}
_KNOWN = {"$schema", "$id", "$defs", "$ref", "$comment", "title", "description", "type", "const",
          "enum", "pattern", "required", "properties", "additionalProperties", "items", "minItems",
          "maxItems", "minLength", "maxLength", "minimum", "uniqueItems", "examples"}


def schema_errors(value, schema, root=None, path="$"):
    """Return a list of 'path: message' strings; empty when the value matches."""
    root = root if root is not None else schema
    unknown = set(schema) - _KNOWN
    if unknown:
        # A keyword this interpreter does not implement would be silently ignored.
        return [f"{path}: schema uses unsupported keywords {sorted(unknown)}"]
    if "$ref" in schema:
        ref = schema["$ref"]
        if not ref.startswith("#/$defs/"):
            return [f"{path}: unsupported $ref {ref}"]
        return schema_errors(value, root["$defs"][ref[len("#/$defs/"):]], root, path)
    errors = []
    types = schema.get("type")
    if types is not None:
        types = types if isinstance(types, list) else [types]
        if not any(_TYPES[t](value) for t in types):
            return [f"{path}: expected {'/'.join(types)}, got {type(value).__name__}"]
    if "const" in schema and value != schema["const"]:
        errors.append(f"{path}: must be {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: must be one of {schema['enum']}")
    if isinstance(value, str):
        if "pattern" in schema and not re.search(schema["pattern"], value):
            errors.append(f"{path}: {value!r} does not match {schema['pattern']}")
        if "minLength" in schema and len(value) < schema["minLength"]:
            errors.append(f"{path}: shorter than {schema['minLength']}")
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            errors.append(f"{path}: longer than {schema['maxLength']}")
    if _TYPES["number"](value) and "minimum" in schema and value < schema["minimum"]:
        errors.append(f"{path}: below {schema['minimum']}")
    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path}: missing {key}")
        properties = schema.get("properties", {})
        extra = schema.get("additionalProperties", True)
        for key, item in value.items():
            if key in properties:
                errors += schema_errors(item, properties[key], root, f"{path}.{key}")
            elif extra is False:
                errors.append(f"{path}: unexpected field {key}")
            elif isinstance(extra, dict):
                errors += schema_errors(item, extra, root, f"{path}.{key}")
    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            errors.append(f"{path}: fewer than {schema['minItems']} items")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{path}: more than {schema['maxItems']} items")
        if schema.get("uniqueItems") and len({canonical(v) for v in value}) != len(value):
            errors.append(f"{path}: items are not unique")
        if "items" in schema:
            for index, item in enumerate(value):
                errors += schema_errors(item, schema["items"], root, f"{path}[{index}]")
    return errors


def check_schema(value, schema_path, what):
    errors = schema_errors(value, load_json(schema_path))
    if errors:
        raise Invalid(f"{what} does not match {os.path.basename(schema_path)}:\n  " + "\n  ".join(errors[:40]))


# --------------------------------------------------------------------------------------
# Catalog and facts


def load_catalog(path=CATALOG):
    catalog = load_json(path)
    if catalog.get("schema") != "sptd-demo-catalog-v1" or catalog.get("nonRelease") is not True:
        raise Invalid(f"{path}: expected schema sptd-demo-catalog-v1 with nonRelease true")
    ids = [step["id"] for step in catalog["steps"]]
    if len(set(ids)) != len(ids):
        raise Invalid(f"{path}: duplicate step ids")
    phases = [phase["name"] for phase in catalog["phases"]]
    order = [phases.index(step["phase"]) for step in catalog["steps"]]
    if order != sorted(order):
        raise Invalid(f"{path}: steps are not grouped in phase order")
    if catalog["phases"][0]["registryMode"] != "fresh" or any(
            p["registryMode"] != "append" for p in catalog["phases"][1:]):
        raise Invalid(f"{path}: the first phase must start a fresh registry, later phases append")
    return catalog


def catalog_demos(catalog):
    """Demo names in catalog order (a demo can have several steps, e.g. software-updates v1/v2)."""
    seen = []
    for step in catalog["steps"]:
        if step["demo"] not in seen:
            seen.append(step["demo"])
    return seen


def select_steps(catalog, demos=None, include_pending=False):
    """Steps of the selected demos, in catalog order. Pending steps only on request."""
    known = catalog_demos(catalog)
    if demos:
        unknown = sorted(set(demos) - set(known))
        if unknown:
            raise Invalid("unknown demo(s): " + ", ".join(unknown) + "; known: " + ", ".join(known))
    chosen = [s for s in catalog["steps"] if not demos or s["demo"] in demos]
    if not include_pending:
        chosen = [s for s in chosen if s["status"] == "ready"]
    return chosen


def load_facts(path):
    facts = load_json(path)
    check_schema(facts, FACTS_SCHEMA, f"facts file {path}")
    if not facts["standIn"]:
        zero = [name for name, value in _digest_fields(facts) if value == ZERO_DIGEST]
        if zero:
            raise Invalid("facts with standIn false must not carry zero digests: " + ", ".join(zero))
        if facts["managerId"].startswith("STAND-IN"):
            raise Invalid("facts with standIn false must name the real manager id")
    return facts


def _digest_fields(value, prefix="facts"):
    if isinstance(value, dict):
        for key, item in value.items():
            yield from _digest_fields(item, f"{prefix}.{key}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            yield from _digest_fields(item, f"{prefix}[{index}]")
    elif isinstance(value, str) and SHA256.match(value):
        yield prefix, value


def bare_pin(pin):
    """envcas and sptd-k8s-node want the root pin as bare hex; onboard.py wants sha256:<hex>."""
    pin = pin[len("sha256:"):] if pin.startswith("sha256:") else pin
    if not HEX64.match(pin):
        raise Invalid("root pin must be 64 lowercase hex digits (optionally sha256:-prefixed)")
    return pin


def plan_file_name(namespace, pod_name):
    """Node file name for a signed Pod plan: provision-dev-registry accepts only
    [a-z0-9]([-a-z0-9.]*[a-z0-9])? up to 128 characters, so '<ns>_<pod>' (the dispatcher's
    collection name) cannot be used as is."""
    name = f"{namespace}.{pod_name}"
    if not re.fullmatch(r"[a-z0-9]([-a-z0-9.]*[a-z0-9])?", name) or len(name) > 128:
        raise Invalid(f"Pod plan name {name!r} is not a valid node plan name")
    return name
