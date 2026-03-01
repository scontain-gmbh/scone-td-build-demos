#!/usr/bin/env bash

set -Eeuo pipefail

TYPE_SPEED="${TYPE_SPEED:-25}"
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"
SHELLRC="${SHELLRC:-/dev/null}"
PROMPT="${PROMPT:-$'\[\e[1;32m\]demo\[\e[0m\]:\[\e[1;34m\]~\[\e[0m\]\$ '}"
COLUMNS="${COLUMNS:-100}"
LINES="${LINES:-26}"
ORANGE="${ORANGE:-\033[38;5;208m}"
LILAC="${LILAC:-\033[38;5;141m}"
RESET="${RESET:-\033[0m}"

slow_type() {
  local text="$*"
  local delay
  delay=$(awk "BEGIN { print 1 / $TYPE_SPEED }")
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:i:1}"
    sleep "$delay"
  done
}

pe() {
  local cmd="$*"
  printf "%b" "$ORANGE"
  slow_type "$cmd"
  printf "%b" "$RESET"
  printf "\n"

  if [[ -n "${PE_BUFFER:-}" ]]; then
    PE_BUFFER+=$'\n'
  fi
  PE_BUFFER+="$cmd"

  # Execute only when buffered lines form a complete shell command.
  if bash -n <(printf '%s\n' "$PE_BUFFER") 2>/dev/null; then
    eval "$PE_BUFFER"
    PE_BUFFER=""
  fi

  sleep "$PAUSE_AFTER_CMD"
}

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export COLUMNS LINES
export PS1="$PROMPT"
stty cols "$COLUMNS" rows "$LINES"

printf "%b" "$LILAC"
printf '%s\n' '# 🛡️ SCONE ConfigMap Example: Secure Your Configurations in Kubernetes'
printf '%s\n' ''
printf '%s\n' 'This example walks you through how to securely manage and access configuration data in Kubernetes using a `ConfigMap` and a SCONE-enabled Rust application. You’ll start with a plain (unencrypted) deployment, then transition to a fully protected SCONE deployment.'
printf '%s\n' ''
printf '%s\n' '![ConfigMap Example](../docs/configmap.gif)'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
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
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '#### 3. Setting up the Environment Variables'
printf '%s\n' ''
printf '%s\n' 'First, we ensure we are in the correct directory. Assumption, we start at directory `scone-td-build-demos`.'
printf '%s\n' ''
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
pushd configmap
EOF
)"
pe "$(cat <<'EOF'
# ensure that the following is not set
EOF
)"
pe "$(cat <<'EOF'
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'The default values of several environment variables are defined in file `Values.yaml`.'
printf '%s\n' '`tplenv` asks you if all defaults are ok. It then sets the environment variables:'
printf '%s\n' ''
printf '%s\n' ' - `$DEMO_IMAGE` - name of the native container image to deploy the application,'
printf '%s\n' ' - `$DESTINATION_IMAGE_NAME` - destination of the confidential container image'
printf '%s\n' ' - `$IMAGE_PULL_SECRET_NAME` the name of the pull secret to pull this image (default is `sconeapps`).  For simplicity, we assume that we can use the same pull secret to run the native and the confidential workload. '
printf '%s\n' ' - `$SCONE_VERSION` - the SCONE version to use (7.0.0-alpha.1) '
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
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file  --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 🧱 4. Build the Native Rust Image'
printf '%s\n' ''
printf '%s\n' 'This step builds a native version of the image to validate behavior before enforcing protection with SCONE.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
pushd folder-reader
EOF
)"
pe "$(cat <<'EOF'
docker build -t ${DEMO_IMAGE} .
EOF
)"
pe "$(cat <<'EOF'
docker push ${DEMO_IMAGE}
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
popd
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🧩 Step 5: Render the Manifest'
printf '%s\n' ''
printf '%s\n' 'To render the manifests, we first need to define the signer key used to sign policies:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
export SIGNER="$(scone self show-session-signing-key)"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We then instantiate the manifest templates:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml  --indent
EOF
)"
pe "$(cat <<'EOF'
tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml  --indent
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '> Make sure the image name was correctly substituted in the manifest.native.yaml file before applying it with kubectl.'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🔑 6. Add Docker Registry Secret to Kubernetes'
printf '%s\n' ''
printf '%s\n' 'We assume that you need a pull secret to pull the native and the confidential container image. We first check if the pull secret is already set. If it is not set, we ask the user to input the necessary information to create the pull secret:'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.'
printf '%s\n' '- `$REGISTRY_USER` - the login name of the user that pulls the container image.'
printf '%s\n' '- `$REGISTRY_TOKEN` - the token to pull the secret. See <https://sconedocs.github.io/registry/> for how to create this token.'
printf '%s\n' ''
printf '%s\n' 'Note that `tplenv` stores this information in file `Values.yaml`. '
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} not exist - creating now."
EOF
)"
pe "$(cat <<'EOF'
  # ask user for the credentials for accessing the registry
EOF
)"
pe "$(cat <<'EOF'
  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry scontain --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🧪 7. Deploy the Native App [OPTIONAL]'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl apply -f manifests/manifest.yaml
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
retry-spinner -- kubectl logs job/my-rust-app -c reader-1
EOF
)"
pe "$(cat <<'EOF'
retry-spinner -- kubectl logs job/my-rust-app -c reader-2
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Clean up native app
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f manifests/manifest.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '✅ Your containers should log content from their mounted ConfigMap files.'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🧩 8. Prepare and Apply the SCONE Manifest'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
scone-td-build from -y manifests/scone.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This step:'
printf '%s\n' ''
printf '%s\n' '- Generates a SCONE session'
printf '%s\n' '- Attaches it to your manifest'
printf '%s\n' '- Produces a new `manifests/manifest.prod.sanitized.yaml` with the necessary information to use the created session'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🚀 9. Deploy the SCONE-Protected App'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl apply -f manifests/manifest.prod.sanitized.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 📜 10. View Logs'
printf '%s\n' ''
printf '%s\n' 'Check that SCONE-protected containers can access the expected ConfigMap data:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
retry-spinner -- kubectl logs job/my-rust-app -c reader-1 --follow
EOF
)"
pe "$(cat <<'EOF'
retry-spinner -- kubectl logs job/my-rust-app -c reader-2 --follow
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🧹 11. Clean Up'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl delete -f manifests/manifest.prod.sanitized.yaml
EOF
)"

