#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

printf "${VIOLET}"
printf '%s\n' '# TDX Workshop'
printf '%s\n' ''
printf '%s\n' 'This runbook provisions a TDX CVM cluster on Azure, installs the SCONE platform with SGX plugin 7.0.0-alpha.1, and runs the full demo suite. Each demo attests the public CAS (`scone-cas.cf`) individually.'
printf '%s\n' ''
printf '%s\n' '## 1. Load Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Load configuration from `workshop/Values.yaml`. We `pushd` into the workshop directory so that tplenv finds `Values.yaml` with the defaults:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
printf '%s\n' 'pushd workshop'
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)'
printf '%s\n' 'popd'
printf "${RESET}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd workshop
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 2. Verify Prerequisites'
printf '%s\n' ''
printf '%s\n' 'Check that all required tools are available:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'for tool in kubectl-scone_azure az kubectl scone-td-build tplenv jq; do'
printf '%s\n' '  if ! command -v "$tool" &>/dev/null; then'
printf '%s\n' '    echo "ERROR: $tool is not installed or not on PATH"'
printf '%s\n' '    exit 1'
printf '%s\n' '  fi'
printf '%s\n' '  echo "OK: $tool"'
printf '%s\n' 'done'
printf "${RESET}"

for tool in kubectl-scone_azure az kubectl scone-td-build tplenv jq; do
  if ! command -v "$tool" &>/dev/null; then
    echo "ERROR: $tool is not installed or not on PATH"
    exit 1
  fi
  echo "OK: $tool"
done

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 3. Create TDX CVM Cluster'
printf '%s\n' ''
printf '%s\n' 'Provision a single-node TDX cluster on Azure. The `--no-attestation` flag skips KBS platform attestation to simplify the flow.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl scone-azure create --tdx \'
printf '%s\n' '  --node-count ${NODE_COUNT} \'
printf '%s\n' '  --memory ${MEMORY} \'
printf '%s\n' '  --vcores ${VCORES} \'
printf '%s\n' '  --scone-config ${CVM_CONFIG} \'
printf '%s\n' '  --kube-config ${KUBECONFIG_PATH} \'
printf '%s\n' '  --credentials ${AZURE_CREDENTIALS} \'
printf '%s\n' '  --rg ${RESOURCE_GROUP} \'
printf '%s\n' '  --no-attestation'
printf "${RESET}"

kubectl scone-azure create --tdx \
  --node-count ${NODE_COUNT} \
  --memory ${MEMORY} \
  --vcores ${VCORES} \
  --scone-config ${CVM_CONFIG} \
  --kube-config ${KUBECONFIG_PATH} \
  --credentials ${AZURE_CREDENTIALS} \
  --rg ${RESOURCE_GROUP} \
  --no-attestation

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Set the kubeconfig and verify the cluster:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export KUBECONFIG=$(realpath ${KUBECONFIG_PATH})'
printf '%s\n' 'kubectl get nodes'
printf '%s\n' 'retry-spinner --timeout 300 --wait 10 -- kubectl wait --for=condition=Ready nodes --all --timeout=10s'
printf "${RESET}"

export KUBECONFIG=$(realpath ${KUBECONFIG_PATH})
kubectl get nodes
retry-spinner --timeout 300 --wait 10 -- kubectl wait --for=condition=Ready nodes --all --timeout=10s

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Install SCONE Platform (SGX Plugin ${SGX_PLUGIN_VERSION})'
printf '%s\n' ''
printf '%s\n' 'Download the operator controller script:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'mkdir -p /tmp/SCONE_OPERATOR_CONTROLLER'
printf '%s\n' 'cd /tmp/SCONE_OPERATOR_CONTROLLER'
printf '%s\n' 'curl -fsSL "https://raw.githubusercontent.com/scontain/SH/master/${SGX_PLUGIN_VERSION}/operator_controller" > operator_controller'
printf '%s\n' 'curl -fsSL "https://raw.githubusercontent.com/scontain/SH/master/${SGX_PLUGIN_VERSION}/operator_controller.asc" > operator_controller.asc'
printf '%s\n' 'chmod a+x operator_controller'
printf '%s\n' 'echo "Downloaded operator_controller for version ${SGX_PLUGIN_VERSION}"'
printf "${RESET}"

mkdir -p /tmp/SCONE_OPERATOR_CONTROLLER
cd /tmp/SCONE_OPERATOR_CONTROLLER
curl -fsSL "https://raw.githubusercontent.com/scontain/SH/master/${SGX_PLUGIN_VERSION}/operator_controller" > operator_controller
curl -fsSL "https://raw.githubusercontent.com/scontain/SH/master/${SGX_PLUGIN_VERSION}/operator_controller.asc" > operator_controller.asc
chmod a+x operator_controller
echo "Downloaded operator_controller for version ${SGX_PLUGIN_VERSION}"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Run the operator controller to install the SGX plugin, SCONE operator, and LAS. We pin `CERT_MANAGER` to avoid pulling a version incompatible with the cluster'\''s Kubernetes release:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export CERT_MANAGER="https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"'
printf '%s\n' 'bash operator_controller \'
printf '%s\n' '  --set-version ${SGX_PLUGIN_VERSION} \'
printf '%s\n' '  --reconcile --update --plugin --verbose \'
printf '%s\n' '  --dcap-api "${DCAP_KEY}" \'
printf '%s\n' '  --secret-operator \'
printf '%s\n' '  --username ${REGISTRY_USER} \'
printf '%s\n' '  --access-token ${REGISTRY_TOKEN} \'
printf '%s\n' '  --email ${REGISTRY_EMAIL}'
printf "${RESET}"

export CERT_MANAGER="https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
bash operator_controller \
  --set-version ${SGX_PLUGIN_VERSION} \
  --reconcile --update --plugin --verbose \
  --dcap-api "${DCAP_KEY}" \
  --secret-operator \
  --username ${REGISTRY_USER} \
  --access-token ${REGISTRY_TOKEN} \
  --email ${REGISTRY_EMAIL}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Wait for the SGX plugin and LAS to become healthy:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'retry-spinner --timeout 600 --wait 15 -- sh -c '\''kubectl get sgx -o jsonpath="{.items[0].status.state}" | grep -q HEALTHY'\'''
printf '%s\n' 'echo "SGX plugin is HEALTHY"'
printf '%s\n' 'retry-spinner --timeout 600 --wait 15 -- sh -c '\''kubectl get las -o jsonpath="{.items[0].status.state}" | grep -q HEALTHY'\'''
printf '%s\n' 'echo "LAS is HEALTHY"'
printf "${RESET}"

retry-spinner --timeout 600 --wait 15 -- sh -c 'kubectl get sgx -o jsonpath="{.items[0].status.state}" | grep -q HEALTHY'
echo "SGX plugin is HEALTHY"
retry-spinner --timeout 600 --wait 15 -- sh -c 'kubectl get las -o jsonpath="{.items[0].status.state}" | grep -q HEALTHY'
echo "LAS is HEALTHY"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Return to the repo root directory (we changed to `/tmp` for the download):'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'cd "${REPO_ROOT}"'
printf "${RESET}"

cd "${REPO_ROOT}"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Run Demos'
printf '%s\n' ''
printf '%s\n' 'Export the CAS variables so they override per-demo defaults (most demos default to a local CAS):'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export CAS_NAME=${CAS_NAME}'
printf '%s\n' 'export CAS_NAMESPACE=${CAS_NAMESPACE}'
printf "${RESET}"

export CAS_NAME=${CAS_NAME}
export CAS_NAMESPACE=${CAS_NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Run all 6 demos:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' './scripts/run-all-scripts.sh'
printf "${RESET}"

./scripts/run-all-scripts.sh

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 6. Cleanup (Optional)'
printf '%s\n' ''
printf '%s\n' 'To delete the cluster, note the cluster name and resource group from the creation output above, then run:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'echo "To delete the cluster, run:"'
printf '%s\n' 'echo "kubectl scone-azure delete --cluster-name <CLUSTER_NAME> --rg <RESOURCE_GROUP> --credentials ${AZURE_CREDENTIALS}"'
printf "${RESET}"

echo "To delete the cluster, run:"
echo "kubectl scone-azure delete --cluster-name <CLUSTER_NAME> --rg <RESOURCE_GROUP> --credentials ${AZURE_CREDENTIALS}"

