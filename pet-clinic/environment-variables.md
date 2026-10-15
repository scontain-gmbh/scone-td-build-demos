This file defines the environment variables used to configure the `pet-clinic` example. The variables below are set with the help of `tplenv`:

1. The native PetClinic application uses a container image.
   The URL of this image is stored in `${IMAGE_NAME}`,
   and it runs in the `${NAMESPACE}` namespace.
2. The URL of the generated confidential container image is stored in `${DESTINATION_IMAGE_NAME}`.
3. The upstream Spring PetClinic commit that the image is built from is stored in `${PETCLINIC_REF}`.
4. The native MariaDB image is stored in `${MARIADB_IMAGE}`.
5. The name of the pull secret for both the native and confidential container images is stored in `${IMAGE_PULL_SECRET_NAME}`.
6. The SCONE version is stored in `${SCONE_RUNTIME_VERSION}`.
   The recommended value is `6.0.8`.
7. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`.
   `${CAS_NAME}` and `${CAS_NAMESPACE}` address the in-cluster CAS for `kubectl` calls.
8. The CAS name is stored in `${CAS_NAME}`.
   The manifests use `${CAS_ENDPOINT}` instead, which defaults to `cas.default`. Point it at
   a public CAS to run against one, for example `CAS_ENDPOINT=edge.scone-cas.cf`.
9. Set `${TEE_TYPE}` to `cvm` for CVM mode or `sgx` for SGX.
10. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
    We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `true`.
11. We need to set the local signer: `${SIGNER}`
    This should already be preset to `scone self show-session-signing-key`
12. The enclave heap of the PetClinic container is stored in `${ENCLAVE_HEAP}`.
    The default is `4G`: the enclave must hold the whole JVM. With EDMM disabled, SGX commits
    the whole heap when the enclave starts, so the node needs enough EPC for it.
13. The database name, user and passwords are stored in `${DB_NAME}`, `${DB_USER}`,
    `${DB_PASSWORD}` and `${DB_ROOT_PASSWORD}`.
