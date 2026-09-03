This file defines the environment variables used to configure the `governance` example. The variables below are collected with `tplenv`:

1. The native application image is stored in `${IMAGE_NAME}`.
2. The URL of the generated confidential container image is stored in `${DESTINATION_IMAGE_NAME}`.
3. The name of the pull secret for both the native and confidential container images is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The SCONE version is stored in `${SCONE_RUNTIME_VERSION}`.
   The recommended value is `7.0.0-alpha.4` (SCONE 6.x runtime sources are no longer supported by lib-sconify).
5. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`.
   The templates resolve `${CAS_NAME}.${CAS_NAMESPACE}` to the CAS endpoint, so for SCONE's public CAS at `scone-cas.cf` set `CAS_NAMESPACE=cf`.
6. The CAS name is stored in `${CAS_NAME}`.
   For SCONE's public CAS, set `CAS_NAME=scone-cas`.
7. If you want to use CVM mode, set `${CVM_MODE}` to `true`. For SGX, set to `false`.
8. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
   We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `true`.
9. The Kubernetes namespace where the demo runs is stored in `${NAMESPACE}`.
10. The governance policy-signing service base URL is stored in `${GOVERNANCE_URL}`.
    This is the "governance website" backend that collects the required signatures.
11. The API token bound to your managed access policy on that service is stored in `${GOVERNANCE_API_TOKEN}`.
    It selects which stored policy and signers apply to your signing requests.
