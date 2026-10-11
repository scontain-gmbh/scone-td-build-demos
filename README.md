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
# Skip the apply if the cluster already serves a registry on NodePort 30500:
kubectl get svc -A | grep -q ':30500/' || kubectl apply -f workshop/local-registry.yaml
./scripts/use-registry.sh localhost:30500
```

The nodes pull `localhost:30500/...` through the NodePort; containerd treats `localhost` as an insecure registry, so no node configuration is needed. The names must use `localhost`, not the node IP, because the nodes refuse plain HTTP for any other host.

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

Use the following examples to learn how `scone-td-build` transforms applications:

- [hello-world](./hello-world/README.md): Build a native `hello-world` program, then transform it into a confidential cloud-native program using `scone-td-build`. You can run all commands with `./scripts/hello-world.sh`. The focus of this example is on how to protect the integrity of the program code.
- [configmap](./configmap/README.md): Protect `ConfigMaps` by transforming them into encrypted CAS policies. This shows how to protect `ConfigMaps`.
- [web-server](./web-server/README.md): Protect `ConfigMaps` and `Secrets` by transforming them into encrypted CAS policies and mapping them as files into a web server. This example uses a `Deployment` instead of a `ConfigMap`.
- [network-policy](./network-policy/README.md): Set up SCONE-protected client/server communication over mTLS in Kubernetes. Build native images first to validate behavior, then move to a fully protected SCONE deployment using a Kubernetes `NetworkPolicy`.
- [flask-redis](./flask-redis/README.md): Deploy a SCONE-protected Flask API backed by Redis with mutual TLS in Kubernetes, including (manual) certificate generation, namespace and secret management, native smoke tests, and full integration tests for `/keys`, `/client`, `/score`, and `/memory`.
- [flask-redis-netshield](./flask-redis-netshield/README.md): Extends `flask-redis` by adding a network policy to encrypt network traffic between `flask` and `redis` services.
- [go-args-env-file](./go-args-env-file/README.md): Deploy a SCONE-protected Go utility that prints command-line arguments, environment variables, and reads two config files from `/config/`. We use a slightly enhanced Go runtime which uses a libc to issue system calls.
- [java-args-env-file](./java-args-env-file/README.md): Deploy a Java utility that prints command-line arguments, environment variables, and reads two config files from `/config/`.
- [image-signing](./image-signing/README.md): Sign and encrypt a confidential container image with a Sigstore key and verify the signature before deploying it to Kubernetes.
- [software-updates](./software-updates/README.md): Perform a **software update** of a confidential Python application. `API_PASSWORD` is encrypted into the CAS session (never visible in any Kubernetes object) and preserved across the rolling update from Version 1 to Version 2.

## Background

- [Kubernetes Basics](Kubernetes_basic_concepts.md): Some basic Kubernetes concepts that we use in our examples.
- [Container Registry Basics](ContainerRegistryBasics.md): Some basic background related to repositories, pull secrets, etc.
- [Create Own Repository](CreatingOwnRepository.md): In the examples, we create new container images and push them to repositories. This document explains how to set up a repository on GitHub.

## Automation and Testing

Each example includes a generated script. These scripts suggest default values and prompt you to confirm or change them. Values are stored in each example's `Values.yaml`.

Once these `Values.yaml` files are initialized, you can run all examples with:

```bash
# Run the generated scripts for all demos.
./scripts/run-all-scripts.sh
```

For GitHub Actions on a self-hosted runner, see [GitHubActionsSelfHosted.md](GitHubActionsSelfHosted.md).

## Cleanup

Note that registry tokens, registry user IDs, and public signer keys are stored in the value files. To remove this data, run:

```bash
./scripts/remove-values-secrets.sh
```
