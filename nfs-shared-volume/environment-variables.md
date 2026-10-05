This file defines the environment variables used to configure the `nfs-shared-volume` example. The variables below are collected with `tplenv`:

1. The native application image (writer/reader) is stored in `${IMAGE_NAME}`.
2. The URL of the generated confidential container image is stored in `${DESTINATION_IMAGE_NAME}`.
3. The name of the pull secret for both the native and confidential container images is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The SCONE version is stored in `${SCONE_RUNTIME_VERSION}`.
   The recommended value is `6.1.0-rc.0`.
5. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`, and its name is stored in `${CAS_NAME}`.
6. The manifests do not derive the endpoint from those two: they use `${CAS_ENDPOINT}`, which
   defaults to `cas.default`. Changing `CAS_NAME` or `CAS_NAMESPACE` alone leaves the sessions
   bound to `cas.default`, so set `CAS_ENDPOINT` as well, for example
   `CAS_ENDPOINT=scone-cas.cf` for SCONE's public CAS.
7. The TEE type is stored in `${TEE_TYPE}`: `sgx` or `cvm`.
8. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
   We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `true`.
9. The Kubernetes namespace where the demo runs is stored in `${NAMESPACE}`.
   The two Deployments share one PVC in this namespace, which is what triggers the NFS re-sharing.
