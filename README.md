# `scone-td-build` Examples

The **SCONE Trust Domain Build** (`scone-td-build`) transforms cloud-native applications into confidential cloud-native applications.

Our overall goal is that no user with access to the cluster, not even the root user, can modify:

- the **code** or the **configuration** of an application
- the data of the application

Beyond **integrity**, we also protect **confidentiality** so that no user with access to the cluster can:

- read configuration files, which might contain source code and keys
- read files used to store application data

This approach works independently of whether we run on machines with Intel TDX, AMD SEV-SNP, or Intel SGX. We guarantee this property even if an adversary has gained access to the CVM itself.

## Prerequisites

- A Kubernetes cluster with SGX (or CVM) nodes, the SCONE operator, LAS, SGX plugin and a CAS. By default the demos use the CAS `cas` in namespace `default`. See [scontain/scone](https://github.com/scontain/scone) for the installation.
- `scone-td-build` **0.4.0 or newer**. Older versions fail with `required arguments were not provided: --cas-address`.
- `kubectl`, `docker`, `tplenv` and `retry-spinner`; `skopeo` and `cosign` for the image-signing demo.
- A pull secret for `registry.scontain.com` (SCONE base images).
- A registry you can **push** to. The defaults push to `registry.scontain.com/k8s-scone-images`, which most tokens cannot write.

Check your tools with:

```bash
./scripts/check-prerequisites.sh
```

### Using an in-cluster registry (workshops)

If you have no registry to push to, run a plain registry inside the cluster and point all demos at it:

```bash
# Reuses a registry already on NodePort 30500, creates workshop/local-registry.yaml if
# the port is free, and stops if an unrelated service holds the port.
./scripts/ensure-local-registry.sh
./scripts/use-registry.sh localhost:30500
```

The nodes pull `localhost:30500/...` through the NodePort. The names must use `localhost`, not the node IP, because the nodes refuse plain HTTP for any other host.

containerd falls back to plain HTTP for `localhost` only with its default registry configuration. If your nodes set `config_path` for registry hosts (for example `/etc/containerd/certs.d`), pulls fail with `server gave HTTP response to HTTPS client` until each node has this file, `/etc/containerd/certs.d/localhost:30500/hosts.toml`:

```toml
server = "http://localhost:30500"

[host."http://localhost:30500"]
  capabilities = ["pull", "resolve"]
```

Check a node with `crictl pull localhost:30500/<image>` after the first push.

This workflow needs the Docker engine **inside the cluster**, for example the `dind` pod of the SCONE toolbox: a Docker engine on your laptop resolves `localhost:30500` to the laptop, not to a cluster node. With laptop Docker and a remote cluster, either push to a registry both can reach (`./scripts/use-registry.sh ghcr.io/<you>`), or forward the port first with `kubectl port-forward -n registry svc/registry 30500:5000` and keep it running while the demos push.

The Docker engine that builds and pushes the images must reach the same name. If it runs in a pod (for example the `dind` pod of the SCONE toolbox), `localhost` is that pod, not the node. Add a sidecar that forwards the pod's `localhost:30500` to NodePort 30500 on its node, in every pod that pushes or inspects images:

```bash
kubectl -n scone-tools patch deployment dind --patch-file workshop/registry-forwarder.patch.yaml
kubectl -n scone-tools patch deployment scone-toolbox --patch-file workshop/registry-forwarder.patch.yaml
```

`use-registry.sh` also marks `localhost:30500` insecure for `skopeo` (image-signing demo) in `~/.config/containers/registries.conf`.

The registry uses plain HTTP and no authentication, and it stores images in an `emptyDir`, so they are lost when the pod restarts and they count against the node's ephemeral storage. The `emptyDir` is capped at 10 GiB. Use it only on a workshop cluster. To use another registry, pass its prefix instead, for example `./scripts/use-registry.sh ghcr.io/<you>`.

### Running the demos on a small cluster

Before a workshop, cache the base images in the Docker engine so participants don't hit Docker Hub rate limits or pull timeouts:

```bash
./scripts/prepull-base-images.sh
```

Between demos, free disk space in the Docker engine:

```bash
./scripts/prune-demo-images.sh
```

To also empty the in-cluster registry from `workshop/local-registry.yaml` (all pushed demo images are lost):

```bash
./scripts/prune-demo-images.sh --registry
```

Delete each demo's namespace when you are done with it, so the next demo has the SGX node's memory.

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

The suite runner loads `/scone-registry/scone-registry-env` when executed inside
the SCONE toolbox, so child demos receive the registry credentials selected during
toolbox setup. Set `SCONE_REGISTRY_ENV_FILE` to load another trusted export file.
The Java demo saves registry choices in the ignored `Values.credentials.yaml` and
stops before creating a secret if any required credential is empty.
Toolbox setup provisions `default`, `java-demo`, `ci-scone-td-build`, and `nfs-demo`
with namespace-scoped demo roles; it does not grant namespace creation to the
service account.

Run `./tests/java-registry.test.sh` for local regression checks of suite credential
inheritance, saved-value precedence, missing credentials, and failed writes.

Each example includes a generated script. These scripts suggest default values and prompt you to confirm or change them. Values are stored in each example's `Values.yaml`.
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
