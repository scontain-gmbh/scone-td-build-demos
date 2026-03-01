#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

printf "${VIOLET}"
printf '%s\n' '# Web Server Demo'
printf '%s\n' ''
printf '%s\n' '## Introduction'
printf '%s\n' ''
printf '%s\n' 'This Rust application serves as a minimalistic web service built using the [Axum](https://github.com/tokio-rs/axum) framework.'
printf '%s\n' 'While it'\''s more functional than a traditional "Web Server" program, it remains straightforward and easy to understand. Let'\''s break it down:'
printf '%s\n' ''
printf '%s\n' '![Web-Server Example](../docs/web-server.gif)'
printf '%s\n' ''
printf '%s\n' '## Endpoints'
printf '%s\n' ''
printf '%s\n' '- **Generate Password Endpoint (`/gen`)**:'
printf '%s\n' ''
printf '%s\n' '  - Generates a random password consisting of alphanumeric characters.'
printf '%s\n' '  - Example Response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "password": "aBcD1234EeFgH5678"'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '- **Print Path Endpoint (`/path`)**:'
printf '%s\n' ''
printf '%s\n' '  - Reads files from the `/config` directory and returns their names and contents.'
printf '%s\n' '  - Example Response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "name": "file1.txt",'
printf '%s\n' '    "content": "This is the content of file1.txt.\n..."'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '- **Print Environment Variable Endpoint (`/env/:env`)**:'
printf '%s\n' ''
printf '%s\n' '  - Retrieves the value of the specified environment variable.'
printf '%s\n' '  - Example Response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "value": "your_env_value_here"'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '## How to Run the Demo'
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
printf '%s\n' 'We build a simple cloud-native `web-server` image. For that we use Rust. Rust is available as a container image `rust:latest` on Dockerhub. We define a `Dockerfile` that uses this Rust image to create a `hello world` image:'
printf '%s\n' ''
printf '%s\n' '- it creates a new Rust crate using `cargo`'
printf '%s\n' '- the new crate is actually defining a `hello world` program'
printf '%s\n' '- we build this project and push it to a repository to which we have push rights:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Ensure we are in the correct directory. Assumption, we start at directory `scone-td-build-demos`'
printf '%s\n' 'pushd web-server'
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'
printf "${RESET}"

# Ensure we are in the correct directory. Assumption, we start at directory `scone-td-build-demos`
pushd web-server
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
printf '%s\n' 'eval \\$(tplenv --file environment-variables.md --create-values-file --eval \\${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

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
printf '%s\n' 'tplenv --file manifest.template.yaml --create-values-file --output  manifest.yaml'
printf "${RESET}"

# customize the job manifest
tplenv --file manifest.template.yaml --create-values-file --output  manifest.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '4. **Register image:**'
printf '%s\n' ''
printf '%s\n' 'Now, we create the native `web-server` application using Rust.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the Scone image for the demo client'
printf '%s\n' 'docker build -t \\${IMAGE_NAME} .'
printf '%s\n' ''
printf '%s\n' '# Push it to the registry'
printf '%s\n' 'docker push \\${IMAGE_NAME}'
printf "${RESET}"

# Build the Scone image for the demo client
docker build -t ${IMAGE_NAME} .

# Push it to the registry
docker push ${IMAGE_NAME}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'When transforming the binaries in the container image for confidential computing, we sign the binaries with a key. `scone-td-build` assumes, by default, that this key is stored in file `identity.pem`. We can generate this file as follows:'
printf '%s\n' ''
printf '%s\n' '- we first check if the file exists, and'
printf '%s\n' '- if it does not yet exist, we create with `openssl`'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if [ ! -f identity.pem ]; then'
printf '%s\n' '  echo "Generating identity.pem ..."'
printf '%s\n' '  openssl genrsa -3 -out identity.pem 3072'
printf '%s\n' 'else'
printf '%s\n' '  echo "identity.pem already exists."'
printf '%s\n' 'fi'
printf "${RESET}"

if [ ! -f identity.pem ]; then
  echo "Generating identity.pem ..."
  openssl genrsa -3 -out identity.pem 3072
else
  echo "identity.pem already exists."
fi

printf "${VIOLET}"
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build register \'
printf '%s\n' '    --protected-image \\${IMAGE_NAME} \'
printf '%s\n' '    --unprotected-image \\${IMAGE_NAME} \'
printf '%s\n' '    --destination-image \\${DESTINATION_IMAGE_NAME} \'
printf '%s\n' '    --push \'
printf '%s\n' '    -s ./storage.json \'
printf '%s\n' '    --enforce /app/web-server \'
printf '%s\n' '    --version \\${SCONE_VERSION}'
printf "${RESET}"

scone-td-build register \
    --protected-image ${IMAGE_NAME} \
    --unprotected-image ${IMAGE_NAME} \
    --destination-image ${DESTINATION_IMAGE_NAME} \
    --push \
    -s ./storage.json \
    --enforce /app/web-server \
    --version ${SCONE_VERSION}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '1. **Test the manifest [optional]**:'
printf '%s\n' ''
printf '%s\n' 'First, we clean up - just in case a previous version is running:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Make sure web-server does not yet run'
printf '%s\n' 'kubectl delete deployment web-server || echo "ok - no web-server deployment yet"'
printf '%s\n' 'kubectl wait --for=delete pod -l app=web-server --timeout=240s'
printf '%s\n' 'kill \\$(cat /tmp/pf-8000.pid) || true'
printf "${RESET}"

# Make sure web-server does not yet run
kubectl delete deployment web-server || echo "ok - no web-server deployment yet"
kubectl wait --for=delete pod -l app=web-server --timeout=240s
kill $(cat /tmp/pf-8000.pid) || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Second, we start the deployment'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifest.yaml'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s'
printf '%s\n' ''
printf '%s\n' '# retry-spinner --retries 40 --wait 10 -- kubectl logs -l app=web-server --pod-running-timeout=2m --timestamps'
printf '%s\n' '# Use this command in another terminal or add `&` at the end of the command to run in the background'
printf '%s\n' 'kubectl port-forward deployment/web-server 8000:8000 &'
printf '%s\n' 'echo \\$! > /tmp/pf-8000.pid'
printf '%s\n' ''
printf '%s\n' 'retry-spinner -- curl http://localhost:8000/env/MY_POD_IP'
printf '%s\n' './test.sh'
printf '%s\n' ''
printf '%s\n' 'kubectl delete -f manifest.yaml'
printf '%s\n' 'kubectl wait --for=delete pod -l app=web-server --timeout=240s'
printf '%s\n' ''
printf '%s\n' '# Close the port forward after the execution'
printf '%s\n' 'kill \\$(cat /tmp/pf-8000.pid) || true'
printf '%s\n' 'rm /tmp/pf-8000.pid'
printf "${RESET}"

kubectl apply -f manifest.yaml
kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s

# retry-spinner --retries 40 --wait 10 -- kubectl logs -l app=web-server --pod-running-timeout=2m --timestamps
# Use this command in another terminal or add `&` at the end of the command to run in the background
kubectl port-forward deployment/web-server 8000:8000 &
echo $! > /tmp/pf-8000.pid

retry-spinner -- curl http://localhost:8000/env/MY_POD_IP
./test.sh

kubectl delete -f manifest.yaml
kubectl wait --for=delete pod -l app=web-server --timeout=240s

# Close the port forward after the execution
kill $(cat /tmp/pf-8000.pid) || true
rm /tmp/pf-8000.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '6. **Convert the manifest**:'
printf '%s\n' ''
printf '%s\n' 'If you want to see how the scone image was registered in scone-td-build, take a look in [register-image](../../../register-image.md) markdown.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build apply \'
printf '%s\n' '    -f manifest.yaml \'
printf '%s\n' '    -c \\${CAS_NAME}.\\${CAS_NAMESPACE} \'
printf '%s\n' '    -s ./storage.json \'
printf '%s\n' '    --manifest-env SCONE_SYSLIBS=1 \'
printf '%s\n' '    --manifest-env SCONE_VERSION=1 \'
printf '%s\n' '    --session-env SCONE_VERSION=1 \'
printf '%s\n' '    --version \\${SCONE_VERSION} -p'
printf "${RESET}"

scone-td-build apply \
    -f manifest.yaml \
    -c ${CAS_NAME}.${CAS_NAMESPACE} \
    -s ./storage.json \
    --manifest-env SCONE_SYSLIBS=1 \
    --manifest-env SCONE_VERSION=1 \
    --session-env SCONE_VERSION=1 \
    --version ${SCONE_VERSION} -p

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '7. **Deploy the new manifest**:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifest.cleaned.yaml'
printf "${RESET}"

kubectl apply -f manifest.cleaned.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '   > For the next step, it is expected that you have a Kubernetes cluster with SGX resource and the presence of a LAS'
printf '%s\n' ''
printf '%s\n' '8. **Run the demo**:'
printf '%s\n' ''
printf '%s\n' 'We wait for the pod to become ready before we try a port-forward to access the `web-server`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl  wait --for=condition=Ready pod -l app="web-server" --timeout=240s'
printf '%s\n' '# being ready does not mean that port is available'
printf '%s\n' 'sleep 20'
printf '%s\n' ''
printf '%s\n' 'kubectl port-forward deployment/web-server 8000:8000 &'
printf '%s\n' '# we keep to PID to be able to delete the port-forward'
printf '%s\n' 'echo \\$! > /tmp/pf-8000.pid'
printf "${RESET}"

kubectl  wait --for=condition=Ready pod -l app="web-server" --timeout=240s
# being ready does not mean that port is available
sleep 20

kubectl port-forward deployment/web-server 8000:8000 &
# we keep to PID to be able to delete the port-forward
echo $! > /tmp/pf-8000.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We now send the first request. We do this with some retry just to ensure that the service is indeed ready to serve requests. '
printf '%s\n' ' '
printf '%s\n' 'We execute the [`test.sh`](./test.sh) to run all of these tests more easily:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Test path - result in error'
printf '%s\n' 'retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path'
printf '%s\n' ''
printf '%s\n' '# Test gen'
printf '%s\n' 'retry-spinner -- curl http://localhost:8000/gen'
printf '%s\n' ''
printf '%s\n' '# Test env'
printf '%s\n' './test.sh'
printf "${RESET}"

# Test path - result in error
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path

# Test gen
retry-spinner -- curl http://localhost:8000/gen

# Test env
./test.sh

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '9. **Uninstall demo**:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete -f manifest.cleaned.yaml'
printf '%s\n' 'kill \\$(cat /tmp/pf-8000.pid) || true'
printf '%s\n' 'rm /tmp/pf-8000.pid'
printf '%s\n' 'popd'
printf "${RESET}"

kubectl delete -f manifest.cleaned.yaml
kill $(cat /tmp/pf-8000.pid) || true
rm /tmp/pf-8000.pid
popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We introduced a simple, yet functional "Web Server" web service in Rust! Feel free to explore and modify this demo to suit your needs.'
printf '%s\n' 'If you have any questions or need further assistance, feel free to ask! 😊🚀'
printf "${RESET}"

