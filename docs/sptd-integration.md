# sptd integration: re-onboarding, artifact set, dev node, deploy-only workflow

Development only (NON_RELEASE). This builds on sptd mode ([sptd-mode.md](sptd-mode.md), on
the sptd demo PR branches): the dispatcher `scripts/sptd/bin/scone-td-build` onboards each
demo offline with `scone-dev-onboard/onboard.py`, which dev-signs every profile, the
profile registry and every Pod plan. Once the kernel team's V7 dev image lands, every demo
must be onboarded again against that image (fresh manager id, rebuilt Go root, envcas and
launcher at the merged SHAs). The pieces here make that one repeatable path:

```text
landed-image facts ──► reonboard_all.py plan ──► reonboard-devvm.sh   (devvm, typed line, dev key)
                                                     │
                                                     ▼
                         reonboard_all.py collect ──► artifact set + manifest.json (artifact-set hash)
                                                     │  publish (owner decision)
                     ┌───────────────────────────────┴───────────────────────────┐
                     ▼                                                           ▼
   provision_dev_node.py (root on the node, typed line)        workflow_dispatch: deploy_demo.py
   RuntimeClass, registry + Pod plans, restart containerd       native ► confidential Ready ► check ► cleanup
```

Nothing here signs, holds or generates a key, and nothing pushes. Signing stays on the devvm
(the dev root key never leaves it); CI only deploys a set that is already signed and pinned
by its hash.

All files are in `scripts/sptd/integration/`:

| File | What it is |
| --- | --- |
| `demos.json` | pinned catalog: re-onboarding order, phases, render commands, deploy checks |
| `landed-image-facts.schema.json` | schema of the facts file of a landed image |
| `facts.standin-envcas-main-20261025.json` | stand-in facts for dry runs (envcas main f69a0a61) |
| `reonboard_all.py` | `plan`, `collect`, `validate`, `set-values` |
| `artifact-manifest.schema.json` | pinned schema of an artifact-set manifest |
| `artifact_manifest.py` | `validate` and `hash` of an artifact-set manifest |
| `provision_dev_node.py` | idempotent dev-node provisioning, `--dry-run` |
| `deploy_demo.py` | deploy-only demo run from an artifact set, `--dry-run` |
| `sptdinteg.py` | shared helpers (JSON Schema subset, canonical hash, catalog, facts) |
| `tests/` | unit tests (`tests/sptd-integration.test.sh`, part of `make test`) |

The proposed workflow is [sptd-integration.workflow.yml.proposed](sptd-integration.workflow.yml.proposed).
Everything is standard-library Python 3 and bash; no PyYAML, jsonschema or cluster is needed
to run or test it.

## Landed-image facts

One JSON file (`sptd-landed-image-facts-v1`, public values only) describes the image every
bundle is onboarded against:

| Field | Meaning |
| --- | --- |
| `nodeImage` | name, digest and runtime contract (`V7` is required: Pod plans need the plan-set contract) |
| `managerId` | the image's fresh manager id |
| `goRoot.artifactDigest` | rootfs artifact of the rebuilt Go root; the go-args bundle must have exactly this artifact |
| `envcas` | rust-envcas commit the onboard tools are built from (checked against `envcas_source` on the devvm), optional `toolDigests` |
| `launcher` | `sealed-per-bundle` (today: each bundle seals its own launcher) or `detached-generic` (every bundle must be `bundle-v2` and bind this launcher digest) |
| `onboard`, `demos` | repository + commit of sptd-hello-container-dev and of this repository to onboard from |
| `devRegistry` | root pin (bare hex) and, if the image already ships a registry, its digest (the set then appends to it) |
| `standIn` | `true` for placeholders: zero digests and `STAND-IN` ids are allowed, and every plan made from it refuses to run |

`facts.standin-envcas-main-20261025.json` uses rust-envcas main `f69a0a61` (2026-10-24, with
#46 Cmd-only, #47 baked volumes and #49 Script profile merged), demos #63 head `b63f4bb6`
(carries #60 and the Python commits), onboard #101 head `e0fc2108` (measured script targets)
and the NON_RELEASE dev root pin. Node image, manager id, Go root and launcher are zero.

## Re-onboarding order (`demos.json`)

The profile registry is append-only: each step appends to the registry of the step before it,
and the node's `--append` path requires the installed profiles to be the first entries of the
new registry. So the order is part of the artifact set (it changes every registry digest)
and is pinned in `demos.json`:

| # | Step | Phase | Notes |
| --- | --- | --- | --- |
| 1 | go-args-env-file | base | Go first (the kernel team registers the Go root first); baked volumes |
| 2 | configmap | base | reader-1/reader-2 images, two-role Job → bare Pod + signed Pod plan; baked |
| 3 | java-args-env-file | base | GraalVM native image; baked |
| 4 | web-server | base | baked `/config`, no `MY_POD_IP` |
| 5 | pet-clinic | base | native-image petclinic; MariaDB stays native (support manifests) |
| 6 | hello-world | append-static | |
| 7 | image-signing | append-static | kbs/keyprovider variant not covered |
| 8 | network-policy | append-static | client + server; hostNetwork |
| 9 | software-updates-v1 | append-script | measured CPython script target |
| 10 | software-updates-v2 | append-script | same output-manifest name as v1 |
| 11 | flask-redis-netshield | append-script | flask-api from #62; the redis role is on unpushed 3bb54bfb |
| 12 | flask-redis | append-script | **pending**: item 99 (flask-api build) and its onboarding line, a8c03eb unpushed, #63 SGX failure |

The base phase is the block-4 set (go-args, configmap reader-1/2, java-args, web-server,
petclinic). Pending steps are left out of a plan unless `--include-pending` is given; the
validator's `--require-complete` then reports the set as incomplete. A `--demos` subset keeps
this order but gives a different registry and hash than the full run.

## (n) Re-onboard all: `reonboard_all.py`

```bash
# 1. Plan (anywhere; signs nothing, runs nothing)
python3 scripts/sptd/integration/reonboard_all.py plan --facts FACTS.json \
  --out PLAN_DIR --namespace sptd-dev --node-name NODE [--demos a,b] [--include-pending]
python3 scripts/sptd/integration/reonboard_all.py plan --facts FACTS.json --dry-run [...]   # print only

# 2. On the devvm, under a typed line (exports below), from a copy of PLAN_DIR:
PLAN_DIR/reonboard-devvm.sh

# 3. The script ends with these two; they can also be run by hand:
python3 PLAN_DIR/integration/reonboard_all.py collect --plan PLAN_DIR/reonboard-plan.json \
  --work "$SPTD_REONBOARD_WORK" --set "$SPTD_REONBOARD_WORK/artifact-set" [--link]
python3 PLAN_DIR/integration/artifact_manifest.py validate "$SPTD_REONBOARD_WORK/artifact-set/manifest.json" \
  --deep --facts PLAN_DIR/facts.json
```

`plan` writes `reonboard-plan.json`, a copy of the facts, `reonboard-devvm.sh` and
`integration/` (these scripts, the catalog and the schemas: the demos commit being onboarded
does not need to contain them). The devvm script expects these exports:
`SPTD_DEV_SIGNING_KEY` (path only, mode 0600, never printed), `SPTD_DEMOS`,
`SPTD_ONBOARD_CHECKOUT`, `SPTD_A8_TOOLS`, `SPTD_SOURCE_LAYOUTS`, `SPTD_REONBOARD_WORK`
(new and empty), optionally `SPTD_VALUES_OVERRIDES` (`{step: {KEY: value}}`, e.g. image names
that match the layouts), `SPTD_A8_MEMORY_ASSEMBLY` and `SPTD_BASE_REGISTRY` (only when the image
ships a registry).

The script:

1. refuses to run for stand-in facts (`exit 3`), when the key file is not 0600, when the
   demos, onboard or `envcas_source` checkouts are not at the facts commits or the demos
   checkout has local changes, when `facts.json` or `integration/demos.json` differ from the
   plan, or when the work directory is not empty;
2. sets `TEE_TYPE=sptd`, `SPTD_ROUTE=a8`, `SPTD_A8_OFFLINE=true` (nothing is pulled or built)
   and the root pin from the facts;
3. per step, in the catalog order: sets `TEE_TYPE`, `SCONE_ENCLAVE` and `NAMESPACE` in the
   demo's `Values.yaml` (`set-values`, the same rule as `prepare-example-ci.sh`, without its
   kubectl steps; tplenv gives `Values.yaml` priority over the environment), renders the
   templates exactly as the README does, runs `scone-td-build apply -f <scone.yaml>` with its
   own `SPTD_WORK_DIR` and `SPTD_A8_REGISTRY` = the previous step's registry, and copies the
   output manifest, the rendered native manifests and the run summary into
   `steps/<id>/`;
4. collects the artifact set and validates it.

What `collect` checks before it writes the set: every role passed (one refusal stops it),
every bundle is `runtimeReady: false` for the plan's root pin, and every step's registry
extends the previous one. It copies (or with `--link` hard-links) each bundle to
`bundles/<step>/<workload>/<container>/`, the final registry to `node-set/`, and each Pod
plan to `node-set/pod-plans/<namespace>.<pod>.json{,.sig,.root.pem}`, so `node-set/` is
exactly the `--from` directory of `sptd-k8s-node provision-dev-registry`.

Found while writing this (the reasons for the per-step directories and the renaming):

- software-updates v1 and v2 write the same `manifest.prod.sanitized.yaml`, and the
  dispatcher's `a8/<demo>.summary.json` and bundle paths are per demo, so v2 overwrote v1.
  Each step now has its own `SPTD_WORK_DIR` and output copy.
- The dispatcher collects plans as `<ns>_<pod>.pod-plan.json`; the node installer accepts
  only `[a-z0-9]([-a-z0-9.]*[a-z0-9])?` names, so `_` is refused there. The set uses
  `<ns>.<pod>.json`.
- Pod plans bind the namespace and the Pod spec, including `nodeName`. Namespace and node
  name are therefore fixed at onboarding, recorded in the manifest and checked by the node
  and deploy scripts.
- flask-redis's `k8s/secret-redis-tls.yaml` holds a generated TLS test key. It is never part
  of the artifact set (the validator refuses PEM private keys anywhere in a set); it must be
  generated where the demo runs.

## (3) Artifact manifest and validator

`artifact-manifest.schema.json` (`sptd-demo-artifact-manifest-v1`, JSON Schema 2020-12,
`additionalProperties: false` throughout) pins per set:

- the facts it was built from (facts file digest, node image digest and contract, manager id,
  Go root, envcas commit, launcher route and digest, root pin), the demos and onboard
  commits, the catalog digest, `nodeName` and `namespace`;
- the registry: digests of `profile-registry.json`, `.sig` and `.root.pem`, the profile names
  in registry order, the history after each step, and `installMode` (`fresh`, or `append`
  when the image already ships a registry);
- the Pod plans: node file name, namespace/pod, digests of the plan, signature and root;
- per demo and step: the output manifest, native and support manifests, and per role the
  workload, container, profile, source image, image reference and manifest digest, and the
  bundle (directory, digests of `checksums.json` and `bundle.json`, profile, contract,
  rootfs artifact and image config digests, launcher digest);
- `files`: every pinned file of the set with its digest; bundle contents are pinned through
  each bundle's `checksums.json`;
- `artifactSetSha256`: SHA-256 of the canonical JSON (sorted keys, no whitespace, UTF-8) of
  the manifest without this field. This is the value the workflow is started with.

```bash
python3 scripts/sptd/integration/artifact_manifest.py validate SET/manifest.json \
  [--expect-hash sha256:…] [--facts FACTS.json] [--require-complete] [--deep] [--no-files]
python3 scripts/sptd/integration/artifact_manifest.py hash SET/manifest.json
```

`validate` checks the schema (with a small built-in interpreter for exactly the keywords the
schema uses; an unsupported keyword is an error, never ignored), the hash and `--expect-hash`,
the catalog digest, order and phases, the registry (append-only history ending at the
installed registry, one role per profile, no extra profiles in a fresh set, node-set profile
names equal to the manifest), the Pod plans (unique names and namespace/pod, all used,
namespace of the set, V7), the Go root and the generic launcher when the facts require them,
the facts file (`--facts`), every pinned file's digest, no unpinned file under `node-set/`
(the installer refuses unknown files), with `--deep` every bundle file against its
`checksums.json`, and no PEM private key in any file it reads. Stand-in sets are refused
unless `--allow-stand-in`.

## (o) Dev node provisioning: `provision_dev_node.py`

```bash
python3 scripts/sptd/integration/provision_dev_node.py --set SET --expect-hash sha256:… --node NODE \
  [--host-exec "ssh root@NODE"] [--archive components.tar --archive-sha256 sha256:…] \
  [--helper-sha256 sha256:…] [--clear] [--dry-run [--assume-state fresh|same|earlier|foreign]]
```

Every step checks first and acts only when needed, so a second run with the same set does
nothing:

1. validate the set and its hash; the node must be the one the set was onboarded for;
2. node component archive: the archive is an input of the image build (scone-domain-kernel
   #210 installs it; `/etc/scone/scone-dev` cannot be archive payload), so the script only
   checks the archive digest locally (optional), that the `sptd-k8s-node` helper is installed
   (optional digest pin) and that `sptd-k8s-node.service` is active (`systemctl enable --now`
   otherwise);
3. RuntimeClass `scone-dev` with handler `scone-dev` (the same object as `bootstrap.yaml` of
   sptd-hello-container-dev #107): applied server-side only when missing; another handler is
   refused;
4. the signed set: it reads the installed registry and plan digests and decides:
   - `fresh` (nothing installed): `provision-dev-registry --from … --root-pin …`;
   - `earlier` (the installed registry is an earlier history entry of this set and the
     installed plans are a subset): the same with `--append`;
   - `same`: nothing;
   - `foreign` (anything else): refused, or with `--clear` `/etc/scone/scone-dev` is moved to
     `/root/scone-dev.moved-<digest>` (never deleted) and the set is installed fresh.
   The installer always runs once without `--confirm` (verify only) and then with it. The set
   goes to `/root/sptd-node-set-<hash>` on the host by a tar pipe through `--host-exec`;
5. `systemctl restart containerd.service` only when the set changed (the CRI reads the set
   only at start), then reads the installed registry digest back.

`--dry-run` executes nothing and prints every host and kubectl action and query, answering
the queries from `--assume-state`. On the real node this runs as root under a typed line.

## (4) Proposed workflow

[sptd-integration.workflow.yml.proposed](sptd-integration.workflow.yml.proposed) is not in
`.github/workflows/` (workflow changes are the owner's). It is `workflow_dispatch` only, with
the inputs `artifact_set_sha256`, `node`, `image_digest` and `demos` (subset; empty = all):

- `prepare`: checks the inputs, fetches the set (placeholder), validates it against the
  pinned hash, computes the demo list and uploads the set as a run artifact;
- `demo` (matrix, `max-parallel: 1`, `fail-fast: false`; hostNetwork Pods share the node's
  ports): `deploy_demo.py` per demo: native run (apply the rendered native manifests, wait,
  demo checks, delete), confidential Pod Ready (support manifests + output manifest; every Pod
  Ready, or Succeeded for Jobs and bare Pods), the demo check (logs regex, or HTTP through
  `kubectl port-forward`, which also reaches a hostNetwork Pod), cleanup (always, also after
  a failure). The report is uploaded per demo.

It deploys only: no onboarding, no signing, no key. Placeholders: the runner label
`RUNNER-LABEL-PLACEHOLDER`, `secrets.PLACEHOLDER_SPTD_KUBECONFIG_B64` (namespaced kubeconfig)
and `secrets.PLACEHOLDER_SPTD_ARTIFACT_SET_SOURCE` (where the devvm publishes the set; the
fetch step fails until it is decided).

## Tests

```bash
bash tests/sptd-integration.test.sh        # or: make test
python3 scripts/sptd/integration/reonboard_all.py plan \
  --facts scripts/sptd/integration/facts.standin-envcas-main-20261025.json --allow-stand-in --dry-run
```

The unit tests (`scripts/sptd/integration/tests/`) build a fake devvm run in the layout the
dispatcher and `onboard.py` leave behind (TEST bytes only, no key) and cover: the catalog
(order, block-4 base, every template exists), the schema interpreter, facts refusals, the
stand-in dry-run plan (order, envcas main commit, `exit 3`, no key value, `bash -n` and
shellcheck), plan files, subsets, `set-values` byte-for-byte against
`prepare-example-ci.sh`'s `upsert_scalar`, collect + validate round trip, tampering (file,
manifest, hash, bundle file with `--deep`), private keys, unpinned node-set files, a broken
registry chain, refused roles, facts mismatches, completeness, the Go root and the generic
launcher, the four node states of the provisioning dry run plus its refusals, the deploy dry
run order and refusals, a stub-kubectl deploy run including cleanup after a failed check, and
the proposed workflow's triggers, inputs and placeholders.

## Open points and owner decisions

- **Order.** The order above is derived from the plan notes (block-4 base, Go first). It is a
  proposal; once a real set is signed, changing it means re-signing.
- **Facts values.** Node image digest, manager id, Go root artifact and the launcher route and
  digest come with the landed V7 image. The dispatcher has no input for the manager id or a
  detached generic launcher (bundle-v2 `detached_bootstrap`); if the landed image needs
  them, td-build-sptd.py needs that input first.
- **Pending demo.** flask-redis waits on item 99, its onboarding line, pushing a8c03eb and
  3bb54bfb, and #63's SGX failure.
- **Publishing the set.** Where the devvm puts the signed set for CI (OCI artifact in a dev
  registry, a release asset, a file share), and whether CI gets the deploy view only
  (no rootfs payload).
- **Runner and access.** The runner label that can reach the dev node's API, the namespaced
  kubeconfig secret, and a trusted route to the node (the Proxmox CA pin is still open).
- **Native images.** The native run pulls the native images named in the rendered manifests;
  the node needs pull access (or the images preloaded) and possibly a pull secret.
- **Demo checks.** The checks in `demos.json` follow the READMEs; regexes of `.` only prove
  that a log exists. They need tightening on the first live run.
- **Provisioning on the node** is a root step on the node with a typed line, not a CI step.
- **Stand-in root pin.** The stand-in facts carry the public NON_RELEASE dev root pin; replace
  it if a different dev root is used for the landed image.
