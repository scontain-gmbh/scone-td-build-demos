This file defines the environment variables used to configure the `software-updates` example. The variables below are collected with `tplenv`:

1. The native version 1 image URL is stored in `${IMAGE_NAME_V1}`.
2. The native version 2 image URL is stored in `${IMAGE_NAME_V2}`.
3. The confidential version 1 image URL is stored in `${DESTINATION_IMAGE_NAME_V1}`.
4. The confidential version 2 image URL is stored in `${DESTINATION_IMAGE_NAME_V2}`.
5. The Kubernetes namespace where the demo manifests are deployed is stored in `${NAMESPACE}`.
   The default value is `default`. The CAS session namespace `SESSION_NAMESPACE` (set in
   Step 1 of `README.md`) is derived from `${NAMESPACE}` and `${CVM_MODE}`, so different
   namespaces or modes never share the same CAS session. It is not collected here.
6. The name of the pull secret for both the native and confidential container images is stored in `${IMAGE_PULL_SECRET_NAME}`.
7. The SCONE version is stored in `${SCONE_RUNTIME_VERSION}`.
   The recommended value is `6.1.0-rc.0`.
8. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`.
9. The CAS name is stored in `${CAS_NAME}`.
10. If you want to use CVM mode, set `${CVM_MODE}` to `true`. For SGX, set to `false`.
11. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
    We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `true`.
12. The local signer key `SIGNER` is set automatically in Step 1 of `README.md` from the
    output of `scone self show-session-signing-key`; it is not collected here.
13. The API user injected into the application is stored in `${API_USER}`.
    The default value is `myself`.
