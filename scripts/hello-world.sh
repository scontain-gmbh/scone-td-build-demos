#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

printf "${VIOLET}"
printf '%s\n' '# 🛡️ SCONE: Hello World'
printf '%s\n' ''
printf '%s\n' '## Steps to Run the Hello World Program'
printf '%s\n' ''
printf '%s\n' '![Hello-World Example](../docs/hello-world.gif)'
printf '%s\n' ''
printf '%s\n' '### 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on registry.scontain.com'
printf '%s\n' '- A Kubernetes cluster'
printf '%s\n' '- The Kubernetes command line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` is installed (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- You installed `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' ''
printf '%s\n' '#### 2. Set up the environment'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide to install tools. The simplest way is to install the tools in a Kubernetes cluster (see [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)).'
printf '%s\n' ''
printf '%s\n' '#### 3. Setting up the Environment Variables'
printf '%s\n' ''
printf '%s\n' 'We build a simple cloud-native `hello world` image. For that we use Rust. Rust is available as a container image `rust:latest` on Dockerhub. We define a `Dockerfile` that uses this Rust image to create a `hello world` image:'
printf '%s\n' ''
printf '%s\n' '- it creates a new Rust crate using `cargo`'
printf '%s\n' '- the new crate is actually defining a `hello world` program'
printf '%s\n' '- we build this project and push it to a repository to which we have push rights:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Ensure we are in the correct directory. Assumption, we start at directory `scone-td-build-demos`'
printf '%s\n' 'pushd hello-world'
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'
printf "${RESET}"

# Ensure we are in the correct directory. Assumption, we start at directory `scone-td-build-demos`
pushd hello-world
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'The default values of several environment variables are defined in file `Values.yaml`.'
printf '%s\n' '`tplenv` asks you if all defaults are ok. It then sets the environment variables:'
printf '%s\n' ''
printf '%s\n' ' - `$IMAGE_NAME` - name of the native container image to deploy the `hello-world` application,'
printf '%s\n' ' - `$DESTINATION_IMAGE_NAME` - destination of the confidential container image'
printf '%s\n' ' - `$IMAGE_PULL_SECRET_NAME` the name of the pull secret to pull this image (default is `sconeapps`).  For simplicity, we assume that we can use the same pull secret to run the native and the confidential workload. '
printf '%s\n' ' - `$SCONE_VERSION` - the SCONE version to use (7.0.0-alpha.1 for now) '
printf '%s\n' ' - `$CAS_NAMESPACE` - the CAS namespace to use (e.g., `default`)'
printf '%s\n' ' - `$CAS_NAME` - The CAS name to use (e.g., `cas`) '
printf '%s\n' ' - `$CVM_MODE` - If you want to have CVM mode, set to `--cvm`. For SGX, leave empty. '
printf '%s\n' ' - `$SCONE_ENCLAVE` - In CVM mode, you can run using confidential Kubernetes nodes (set to `--scone-enclave`) or Kata-Pods (leave it empty). '
printf '%s\n' ''
printf '%s\n' 'Program `tplenv` asks the user if our current (default) configuration stored in `Values.yaml`.'
printf '%s\n' 'The user can modify the configuration if needed by setting the following variable to `--force`.'
printf '%s\n' 'Replace the `--force` by `""` to only ask for variables that are not defined in the environment'
printf '%s\n' 'or the Values.yaml file. Note that the `Values.yaml` file has priority over the environment variables.'
printf '%s\n' 'If the user changes values, they are written to `Values.yaml`.'
printf '%s\n' ''
printf '%s\n' 'Ensure that we ask the user to confirm or modify all environment variables:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"'
printf '%s\n' ''
printf '%s\n' '`tplenv` will now ask the user for all environment variables that are described in file `environment-variables.md`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval \\$(tplenv --file environment-variables.md --create-values-file --context --eval \\${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We encrypt the policies that we send to CAS to ensure the integrity and confidentiality of the policies. To do so, we need to attest the CAS. We do this using a plugin of `kubectl` that attests the CAS via the Kubernetes API:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# attest the CAS - to ensure that we know the correct session encryption key'
printf '%s\n' 'kubectl scone cas attest --namespace \\${CAS_NAMESPACE}  \\${CAS_NAME}'
printf "${RESET}"

# attest the CAS - to ensure that we know the correct session encryption key
kubectl scone cas attest --namespace ${CAS_NAMESPACE}  ${CAS_NAME}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'In case the attestation and verification of the CAS would fail, please read the output of `kubectl scone cas attest` to determine which vulnerabilities were detected. It also suggests which options to pass to `kubectl scone cas attest` to tolerate these vulnerabilities, i.e., to make the attestation and verification to succeed.'
printf '%s\n' ''
printf '%s\n' 'Next, we need to customize the job manifest to set the right image name (`$IMAGE_NAME`) and the right pull secret (`$IMAGE_PULL_SECRET_NAME`):'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# customize the job manifest'
printf '%s\n' 'tplenv --file manifest.job.template.yaml --create-values-file --output  manifest.job.yaml'
printf "${RESET}"

# customize the job manifest
tplenv --file manifest.job.template.yaml --create-values-file --output  manifest.job.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '#### 4. Build and Register Image'
printf '%s\n' ''
printf '%s\n' 'Now, we create the native `hello-world` application using Rust. Note that we could create the `hello-world` program within the `Dockerfile` (see below) that we use to build the native container image. To simplify the customization of this example, we create the Rust files. '
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# create the hello-world application'
printf '%s\n' 'cargo new hello-world || echo "Hello World already exists - using existing one"'
printf "${RESET}"

# create the hello-world application
cargo new hello-world || echo "Hello World already exists - using existing one"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We compile the application within a Rust image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# build the hello-world app in a Container'
printf '%s\n' 'docker build -t \\$IMAGE_NAME .'
printf "${RESET}"

# build the hello-world app in a Container
docker build -t $IMAGE_NAME .

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If you have access rights to push to `$IMAGE_NAME`, then push the container image. If you use the default image name, you can use the pre-build container image (i.e., no need to push the image).'
printf '%s\n' ''
printf '%s\n' 'docker push $IMAGE_NAME'
printf '%s\n' ''
printf '%s\n' '## 5. Sconifying the Application'
printf '%s\n' ''
printf '%s\n' 'We need to identify the programs that need to run confidential. To do so, we identify all programs on the image that might run confidential. We can explicitly specify all binaries that need to be confidential using the following options to program `scone-td-build register`:'
printf '%s\n' ''
printf '%s\n' '-  `--enforce <ENFORCE>` '
printf '%s\n' '          Set the enforce binary to ensure that these binaries in the protected image are executed confidentially in the destination image. To define multiple binaries, just use this flag multiple times'
printf '%s\n' ''
printf '%s\n' '- `--enforce-list <ENFORCE_LIST>`'
printf '%s\n' '          Specify a file that contains a list of binary filenames in the protected image. All binaries in the list will run confidential in the destination image'
printf '%s\n' ''
printf '%s\n' 'Alternatively, we could assume that all binaries might run confidential. That might result in many programs being transformed.  To reduce the number of binaries that need to be transformed and to reduce the effort to specify all confidential binaries, we use the following approach:'
printf '%s\n' ''
printf '%s\n' '- `scone-td-build register` first determines all programs of a base image: we call this image the  `unprotected-image`'
printf '%s\n' '- `scone-td-build register` then determines all programs of the container image used by the cloud-native application:  we call this image the `protected-image`'
printf '%s\n' ''
printf '%s\n' 'We register a new image for a later manifest translation: the manifest is protected such that an admin of the Kubernetes cluster cannot modify or read the `ConfigMaps` and `Secrets` of an application.'
printf '%s\n' ''
printf '%s\n' 'Our translation generates a new image that is the original image name extended by postfix `-scone` unless we define a new image name with option `--destination-image`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build register --protected-image \\$IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json --destination-image \\${DESTINATION_IMAGE_NAME} --push --version \\${SCONE_VERSION} \\${CVM_MODE}'
printf "${RESET}"

scone-td-build register --protected-image $IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json --destination-image ${DESTINATION_IMAGE_NAME} --push --version ${SCONE_VERSION} ${CVM_MODE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Note that `register` of images permits us to copy images into our own repository. In this way, we can decouple our application from changes in the upstream repository that contain the original container image (i.e., in our case, `$IMAGE_NAME`)'
printf '%s\n' ''
printf '%s\n' '#### 6. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'We assume that you need a pull secret to pull the native and the confidential container image. We first check if the pull secret is already set. If it is not set, we ask the user to input the necessary information to create the pull secret:'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.'
printf '%s\n' '- `$REGISTRY_USER` - the login name of the user that pulls the container image.'
printf '%s\n' '- `$REGISTRY_TOKEN` - the token to pull the secret. See <https://sconedocs.github.io/registry/> for how to create this token.'
printf '%s\n' ''
printf '%s\n' 'Note that `tplenv` stores this information in file `Values.yaml`. '
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if kubectl get secret "\\${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret \\${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret \\${IMAGE_PULL_SECRET_NAME} not exist - creating now."'
printf '%s\n' '  # ask user for the credentials for accessing the registry'
printf '%s\n' '  eval \\$(tplenv --file registry.credentials.md --create-values-file --eval --force )'
printf '%s\n' '  kubectl create secret docker-registry scontain --docker-server=\\$REGISTRY --docker-username=\\$REGISTRY_USER --docker-password=\\$REGISTRY_TOKEN'
printf '%s\n' 'fi'
printf "${RESET}"

if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} not exist - creating now."
  # ask user for the credentials for accessing the registry
  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )
  kubectl create secret docker-registry scontain --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '#### 7. Convert the manifests'
printf '%s\n' ''
printf '%s\n' 'Next, we use the native Kubernetes manifests and transform them into *sanitized* manifests '
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build apply -f manifest.job.yaml -c \\${CAS_NAME}.\\${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0  \\${CVM_MODE} \\${SCONE_ENCLAVE}'
printf "${RESET}"

scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0  ${CVM_MODE} ${SCONE_ENCLAVE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '#### 8. Apply the new manifest'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Ensure that previous run is not running anymore'
printf '%s\n' 'kubectl delete job hello-world || echo "ok - no previous job that we need to delete"'
printf '%s\n' 'kubectl apply -f manifest.job.cleaned.yaml'
printf "${RESET}"

# Ensure that previous run is not running anymore
kubectl delete job hello-world || echo "ok - no previous job that we need to delete"
kubectl apply -f manifest.job.cleaned.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We need to sleep a little before log output of job becomes available. Hence, we execute the'
printf '%s\n' 'command within a retry wrapper `retry-spinner`:'
printf '%s\n' ''
printf '%s\n' 'Let'\''s see the output of the job'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'retry-spinner -- kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps'
printf "${RESET}"

retry-spinner -- kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '#### 9. Uninstall `hello-world`'
printf '%s\n' ''
printf '%s\n' 'Delete the job that we just created:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete job hello-world '
printf '%s\n' 'popd'
printf "${RESET}"

kubectl delete job hello-world 
popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '### Automation'
printf '%s\n' ''
printf '%s\n' 'You can automatically executing the steps of this  document by executing `./scripts/hello-world.sh`.  Note, that this will not ask for any user inputs: it will use the configuration in file `Values.yaml` (in directory `hello-world`).'
printf '%s\n' ''
printf '%s\n' 'In case you update the commands within this document, you would need to run `/scripts/extract-all-scripts.sh` to re-generate `./scripts/hello-world.sh`.'
printf "${RESET}"

