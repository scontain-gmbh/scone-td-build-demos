This file defines the environment variables used to configure this `hello-world` example. The variables below are set with the help of `tplenv`:

1. The original cloud-native `hello-world` application uses a container image.
   The URL of this image is stored in `${IMAGE_NAME}`.
2. The URL of the generated confidential container image is stored in `${DESTINATION_IMAGE_NAME}`.
3. The name of the pull secret for both the native and confidential container images is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The SCONE version is stored in `${SCONE_RUNTIME_VERSION}`.
   The current value is `6.1.0-rc.0`.
5. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`.
   `${CAS_NAME}` and `${CAS_NAMESPACE}` address the in-cluster CAS for `kubectl` calls.
6. The CAS name is stored in `${CAS_NAME}`.
   The manifests use `${CAS_ENDPOINT}` instead, which defaults to `cas.default`. Point it at
   a public CAS to run against one, for example `CAS_ENDPOINT=edge.scone-cas.cf`.
7. Set `${TEE_TYPE}` to `cvm` for CVM mode or `sgx` for SGX.
8. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods (set to empty).
   We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `true`.
9. The Kubernetes namespace where the demo manifests are deployed is stored in `${NAMESPACE}`.
   The default value is `default`.
