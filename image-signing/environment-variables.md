This file defines the environment variables used to configure this `image-signing` example. The variables below are set with the help of `tplenv`:

1. The original cloud-native `image-signing` application uses a container image.
   The URL of this image is stored in `${IMAGE_NAME}`.
2. The URL of the generated confidential container image is stored in `${DESTINATION_IMAGE_NAME}`.
   When `--destination-image` is set, the signed and encrypted image is pushed directly to `${DESTINATION_IMAGE_NAME}` (no `-encrypted` suffix).
3. The name of the pull secret for both the native and confidential container images is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The path to the Docker credentials file used by the signing push flow is stored in `${REPO_CREDENTIALS}`.
   The default value is `~/.docker/config.json`.
5. The SCONE version is stored in `${SCONE_RUNTIME_VERSION}`.
   The current value is `6.0.8`.
6. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`.
   `${CAS_NAME}` and `${CAS_NAMESPACE}` address the in-cluster CAS for `kubectl` calls.
7. The CAS name is stored in `${CAS_NAME}`.
   The manifests use `${CAS_ENDPOINT}` instead, which defaults to `cas.default`. Point it at
   a public CAS to run against one, for example `CAS_ENDPOINT=edge.scone-cas.cf`.
8. Set `${TEE_TYPE}` to `cvm` for CVM mode or `sgx` for SGX.
9. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
   We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `true`.
10. The Kubernetes namespace where the demo manifests are deployed is stored in `${NAMESPACE}`.
    The default value is `ci-scone-td-build`.
11. The container registry hostname is stored in `${REGISTRY}`.
    The default value is `registry.scontain.com`.
