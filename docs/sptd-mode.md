# sptd mode for the demo scripts (design draft, 2026-10-18)

Goal: `scripts/run-all-scripts.sh` runs every demo on a single-node SPTD cluster (VM 163):
first as a native app, then as a confidential app made of SCONE Process TDs built by
scone-sptd-build. No CVM or CAS attestation at this stage. Workloads use the dev test-launcher
envcas with embedded secrets.

## Existing flow (every demo README, extracted into `scripts/<demo>.sh`)

1. `tplenv` renders `Values.yaml`, the manifests and `scone.yaml`.
2. Native: `docker build` and `docker push $IMAGE_NAME`, a pull secret, `kubectl apply` of the
   native manifest, a check, then `kubectl delete` of the native objects.
3. `kubectl scone cas attest … || scone cas attest … || echo "CAS attestation skipped …"`.
4. `scone-td-build apply -f scone.yaml`: `Register` builds the protected image, `Apply` writes
   `output-manifest` (for example `manifest.job.sanitized.yaml`).
5. `kubectl apply` of the output manifest, a check, then cleanup.

## Proposal: the mode lives in one place, and the READMEs stay as they are

- `prepare-example-ci.sh --mode sptd` sets `TEE_TYPE=sptd` and `SCONE_ENCLAVE='false'` in every
  `Values.yaml`, the same way `sgx` and `cvm` do. `--mode sgx|cvm` and `--namespace` behave
  exactly as today; the CI workflow `test-examples-self-hosted.yml` keeps working unchanged.
- `scripts/sptd/bin/scone-td-build` is a small dispatcher. When `TEE_TYPE` is not `sptd`, it
  execs the real `scone-td-build` with the same arguments. When `TEE_TYPE=sptd`, it handles
  `apply -f scone.yaml` itself:
  1. Reads the `Register` and `Apply` documents. It uses `source-image`, `output-image`,
     `file` and `output-manifest`, and ignores the CAS, `scone-version` and SCONE env fields.
  2. Copies each `source-image` (the image the native step just pushed) to a local OCI
     layout with `skopeo copy docker://… oci:…`, and records its manifest digest.
  3. Runs `scone-sptd-build dev-prepare` phase 1 (NON_RELEASE, being built by the sptd-build
     thread): `--image-layout --image-digest --workload <doc> [--configmap …] --container
     <name>`. It writes `embedded-configuration.json` and its digest. CAS is bypassed and
     only public plaintext inputs are used.
  4. Builds the static dev envcas test launcher from that embedded configuration.
  5. Runs `dev-prepare` phase 2 (`--launcher-root --envcas --envcas-digest`). It writes an OCI
     layout plus the confidential manifest, with the image replaced by the output digest and
     the scone RuntimeClass set.
  6. Signs for VM 163's NON_RELEASE dev pod signer with the onboarding tooling from
     sptd-build #108 (`make_profile_index.py`, issuer). The key path comes from
     `SPTD_POD_SIGNER_KEY`.
  7. Delivers the image: `skopeo copy oci:… docker://$output-image` to the demo registry,
     or preload into VM 163's containerd.
  8. Writes `output-manifest` under the same name, adding, until S7, `hostNetwork: true`,
     `nodeName` and a `node.kubernetes.io/not-ready` toleration.
  Before step 3 it can run `scone-sptd-build build` on a generated input root (SDV-026
  harness) to report compiler refusals early.
- `scripts/run-all-scripts.sh` and `scripts/prepare-example-ci.sh` print the one PATH line
  that sptd mode needs: `export PATH="$PWD/scripts/sptd/bin:$PATH"`. Alternatively the CI
  job sets it.
- Step 3 already degrades to "CAS attestation skipped" when no CAS answers. sptd mode keeps
  that and logs that attestation is off in this mode.

So steps 1, 2, 3 and 5 of every README run unchanged, and step 4 produces the same file
names. No generated `scripts/<demo>.sh` needs to be edited by hand.

## Open points

1. **Native Pods need a Pod network.** The dev kernel has no veth, bridge or nf_tables
   (PXQ-018), so VM 163 has no CNI. Native manifests that aren't hostNetwork won't start,
   and Service names (flask-redis `redis`) resolve in neither mode. A kernel-config change
   fixes the native side; the confidential side also needs S7 (RFA-124, sptd-N8).
2. **Ports.** Under hostNetwork, native objects must be gone before the confidential ones
   start. The READMEs already delete the native objects first; check each demo for leftovers
   (Services, ConfigMaps on fixed ports).
3. **Image delivery.** Either push the sptd-built OCI image to the demo registry
   (`output-image`), or preload it into VM 163's containerd. The preload tool from
   sptd-hello-container-dev `milestone4/clock_image_preload.py` checks bytes and node binding,
   but it runs inside the VM.
4. **Signer.** The bundles must be signed for VM 163's NON_RELEASE dev pod signer. The
   dispatcher takes the key path from `SPTD_POD_SIGNER_KEY` and never copies it.
5. **runc under the SPTD kernel's SELinux policy.** This is untested; the first native run
   shows it.
6. **`kubectl port-forward`** on hostNetwork reaches the node's localhost (gap C9).
7. **Per-demo compiler refusals** (VOLUME, ArgsEscaped, interpreter argv0, Downward API,
   canary hits). Listed with fixes in `sdv026/` results once the all-demo build run is done.
