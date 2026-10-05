This file defines the environment variables used to configure the `governance` example. The variables below are collected with `tplenv`:

1. The native application image is stored in `${DEMO_IMAGE}`.
2. The URL of the generated confidential container image is stored in `${DESTINATION_IMAGE_NAME}`.
3. The name of the pull secret for both the native and confidential container images is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The SCONE version is stored in `${SCONE_RUNTIME_VERSION}`.
   The recommended value is `7.0.0-alpha.4` (SCONE 6.x runtime sources are no longer supported by lib-sconify).
5. The CAS endpoint the sessions are bound to is stored in `${CAS_ENDPOINT}`, normally `${CAS_NAME}.${CAS_NAMESPACE}`.
6. The TEE type is stored in `${TEE_TYPE}`: `sgx` or `cvm`.
7. In CVM mode you can run on confidential Kubernetes nodes or Kata Pods; set `${SCONE_ENCLAVE}` to `true` for confidential nodes.
8. The Kubernetes namespace where the demo runs is stored in `${NAMESPACE}`.
9. The governance policy-signing service base URL is stored in `${GOVERNANCE_URL}`.
   This is the "governance website" backend that collects the required signatures.
10. The API token bound to your managed access policy on that service is stored in `${GOVERNANCE_API_TOKEN}`.
