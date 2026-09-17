This file defines the environment variables used to configure this demo. The variables below are set with the help of `tplenv`:

1. The original cloud-native application uses a container image.
   The URL of this image is stored in `$IMAGE_NAME`.
2. The URL of the generated confidential container image is stored in `$DESTINATION_IMAGE_NAME`.
3. The name of the pull secret for both the native and confidential container images is stored in `$IMAGE_PULL_SECRET_NAME`.
   The default value is `sconeapps`.
4. The SCONE runtime version is stored in `$SCONE_RUNTIME_VERSION`.
   The current value is `6.1.0-rc.0`.
5. The SCONE CAS address is stored in `$CAS_ENDPOINT`.
   For SCONE's public CAS, use `scone-cas.cf`.
6. Select the attestation backend with `$TEE_TYPE`: use `sgx` for SGX and `cvm` for CVM.
7. `$SCONE_ENCLAVE` is a boolean indicating whether a CVM workload runs in a confidential enclave.
8. The Kubernetes namespace where the demo manifests are deployed is stored in `$NAMESPACE`.
   The default value is `default`.
9. Docker registry that stores the protected image: `$REGISTRY`.
10. Your username in this registry: `$REGISTRY_USER`.
11. Your token for this registry: `$REGISTRY_TOKEN`.
