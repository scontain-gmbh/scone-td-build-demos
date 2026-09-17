This file defines the environment variables used to configure the `flask-redis-netshield` example. The variables below are collected with `tplenv`:

1. The URL of the Flask API image is stored in `${IMAGE_NAME}`.
2. The Kubernetes namespace used for all resources is stored in `${NAMESPACE}`.
3. The image pull secret name used by Kubernetes deployments is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The SCONE version is stored in `${SCONE_RUNTIME_VERSION}`.
   The current value is `6.1.0-rc.0`.
5. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`.
   `${CAS_NAME}` and `${CAS_NAMESPACE}` address the in-cluster CAS for `kubectl` calls.
6. The CAS name is stored in `${CAS_NAME}`.
   The manifests use `${CAS_ENDPOINT}` instead, which defaults to `cas.default`. Point it at
   a public CAS to run against one, for example `CAS_ENDPOINT=edge.scone-cas.cf`.
7. Set `${TEE_TYPE}` to `cvm` for CVM mode or `sgx` for SGX.
8. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
   We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `true`.
9. Set the local signer key in `${SIGNER}`.
   This should already be set to the output of `scone self show-session-signing-key`.
