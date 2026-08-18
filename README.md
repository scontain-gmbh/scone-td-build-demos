# `scone-td-build` Examples

The **SCONE Trust Domain Build** (`scone-td-build`) transforms cloud-native applications into confidential cloud-native applications.

Our overall goal is that no user with access to the cluster, not even the root user, can modify:

- the **code** or the **configuration** of an application
- the data of the application

Beyond **integrity**, we also protect **confidentiality** so that no user with access to the cluster can:

- read configuration files, which might contain source code and keys
- read files used to store application data

This approach works independently of whether we run on machines with Intel TDX, AMD SEV-SNP, or Intel SGX. We guarantee this property even if an adversary has gained access to the CVM itself.

## Examples

All demos can be run with `./scripts/demos/<demo-name>.sh` from any working directory. To follow a demo by hand, run the commands of its README from the demo's directory (`demos/<demo-name>`).

Use the following examples to learn how `scone-td-build` transforms applications:

- [hello-world](./demos/hello-world/README.md): Build a native `hello-world` program, then transform it into a confidential cloud-native program using `scone-td-build`. This examples shows how to protect the integrity of the program code.
- [configmap](./demos/configmap/README.md): Protect `ConfigMaps` by transforming them into encrypted CAS policies. This shows how to protect `ConfigMaps`.
- [web-server](./demos/web-server/README.md): Protect `ConfigMaps` and `Secrets` by transforming them into encrypted CAS policies and mapping them as files into a web server. This example uses a `Deployment` instead of a `ConfigMap`.
- [network-policy](./demos/network-policy/README.md): Set up SCONE-protected client/server communication over mTLS in Kubernetes. Build native images first to validate behavior, then move to a fully protected SCONE deployment using a Kubernetes `NetworkPolicy`.
- [flask-redis](./demos/flask-redis/README.md): Deploy a SCONE-protected Flask API backed by Redis with mutual TLS in Kubernetes, including (manual) certificate generation, namespace and secret management, native smoke tests, and full integration tests for `/keys`, `/client`, `/score`, and `/memory`.
- [flask-redis-netshield](./demos/flask-redis-netshield/README.md): Extends `flask-redis` by adding a network policy to encrypt network traffic between `flask` and `redis` services.
- [go-args-env-file](./demos/go-args-env-file/README.md): Deploy a SCONE-protected Go utility that prints command-line arguments, environment variables, and reads two config files from `/config/`. We use a slightly enhanced Go runtime which uses a libc to issue system calls.
- [java-args-env-file](./demos/java-args-env-file/README.md): Deploy a Java utility that prints command-line arguments, environment variables, and reads two config files from `/config/`.
- [software-updates](./demos/software-updates/README.md): Perform a **software update** of a confidential Python application. `API_PASSWORD` is encrypted into the CAS session (never visible in any Kubernetes object) and preserved across the rolling update from Version 1 to Version 2.
- [image-signing](./demos/image-signing/README.md): Sign and encrypt a confidential container image with a Sigstore private key, then verify the signature before deploying it to Kubernetes.
- [pet-clinic](./demos/pet-clinic/README.md): This demo runs the upstream [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) application confidentially inside an Intel SGX enclave using SCONE, backed by a native MariaDB. The Java application (JVM, heap, and the JDBC credentials it uses) is protected inside the enclave and attests to a CAS before it starts.

## Background

- [Kubernetes Basics](docs/basics/Kubernetes_basic_concepts.md): Some basic Kubernetes concepts that we use in our examples.
- [Container Registry Basics](docs/basics/ContainerRegistryBasics.md): Some basic background related to repositories, pull secrets, etc.
- [Create Own Repository](docs/create-own-repository/CreatingOwnRepository.md): In the examples, we create new container images and push them to repositories. This document explains how to set up a repository on GitHub.

## Automation and Testing

Each example includes a generated script in `scripts/demos/`. These scripts suggest default values and prompt you to confirm or change them. Values are stored in each example's `Values.yaml` (seeded from its `values.template.yaml` on the first run). If you edit a README, regenerate the scripts with `./scripts/extract-all-demo-scripts.sh -y`.

Once these `Values.yaml` files are initialized, you can run all examples with:

```bash
# Run the generated scripts for all demos.
./scripts/run-all-demos.sh
```

For GitHub Actions on a self-hosted runner, see [GitHubActionsSelfHosted.md](docs/basics/GitHubActionsSelfHosted.md).

## Cleanup

Note that registry tokens, registry user IDs, and public signer keys are stored in the value files. To remove this data, run:

```bash
./scripts/remove-values-secrets.sh
```
