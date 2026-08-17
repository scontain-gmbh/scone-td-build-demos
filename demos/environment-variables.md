This file defines the environment variables used to configure this demo. The variables below are set with the help of `tplenv`:

1. The original cloud-native application uses a container image.
   The URL of this image is stored in `$NATIVE_IMAGE_NAME`.
2. The URL of the generated confidential container image is stored in `$DESTINATION_IMAGE_NAME`.
3. The name of the pull secret for both the native and confidential container images is stored in `$IMAGE_PULL_SECRET_NAME`.
   The default value is `sconeapps`.
4. The SCONE runtime version is stored in `$SCONE_RUNTIME_VERSION`.
   The current value is `7.0.0-alpha.4`.
   In CVM mode, use `$SCONE_RUNTIME_IMAGE` instead of `$SCONE_RUNTIME_VERSION`.
5. The SCONE CAS address is stored in `$SCONE_CAS_ADDR`.
   For SCONE's public CAS, use `scone-cas.cf`.
6. In CVM mode, the trusted CVM signing key is stored in `$CVM_SIGNING_KEY_FILE`.
   You can extract it as follows:
   ```bash
   curl -sk \
       "$SCONE_CAS_ADDR/v1/values/session=kbs-certs,secret=kbs_ca" | \
       jq -er '.value' | \
       openssl x509 -pubkey -noout > /tmp/kbs-signer.pem
   ```
   Set `$CVM_SIGNING_KEY_FILE` to `/tmp/kbs-signer.pem`.
7. To use CVM mode, set `$CVM_MODE` to `true`. For SGX, leave it empty.
8. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
   We recommend using confidential nodes and setting `$SCONE_ENCLAVE` to `true`.
9. The Kubernetes namespace where the demo manifests are deployed is stored in `$NAMESPACE`.
   The default value is `default`.
10. Docker registry that stores the protected image: `$REGISTRY`.
11. Your username in this registry: `$REGISTRY_USER`.
12. Your token for this registry: `$REGISTRY_TOKEN`.
