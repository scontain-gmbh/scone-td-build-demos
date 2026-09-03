#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from governance/README.md.

Options:
  --help             Show this help message and exit.
  --non-interactive  Do not force confirmation for existing tplenv values.
USAGE
}

NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      unset CONFIRM_ALL_ENVIRONMENT_VARIABLES || true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option '$1'." >&2
      show_help >&2
      exit 1
      ;;
    *)
      echo "Error: This script does not accept positional arguments." >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  echo "Error: This script does not accept positional arguments." >&2
  show_help >&2
  exit 1
fi

if ! $NON_INTERACTIVE; then
  CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
expected_workdir="$(cd "${script_dir}/.." && pwd)"
expected_invocation="./$(basename "${script_dir}")/$(basename "$0")"

if [[ "$(pwd)" != "$expected_workdir" ]]; then
  echo "Error: Wrong working directory." >&2
  echo "Expected working directory: $expected_workdir" >&2
  echo "Run this script as: $expected_invocation" >&2
  exit 1
fi

printf "${VIOLET}"
printf '%s\n' '# SCONE: Governance-approved CAS policy'
printf '%s\n' ''
printf '%s\n' 'This example shows `scone-td-build`'\''s **governance** flow: the generated CAS session'
printf '%s\n' 'policies are not signed locally by whoever runs the build. They are submitted to the'
printf '%s\n' '**policy-signing service**, approved by the required signers, and the `SignedPolicy`'
printf '%s\n' 'resources are assembled from the signatures the service returns.'
printf '%s\n' ''
printf '%s\n' 'The demo proves the approval actually gates the deployment, with two cases:'
printf '%s\n' ''
printf '%s\n' '| Case | What happens |'
printf '%s\n' '|---|---|'
printf '%s\n' '| **Approved** | every session comes back signed, the CAS accepts the policies, the confidential workload attests and CAS delivers it a secret the policy grants |'
printf '%s\n' '| **Refused** | a signer aborts the request, `scone-td-build apply` stops with an error and **nothing is produced to deploy** |'
printf '%s\n' ''
printf '%s\n' 'The app (`app.py`) is deliberately trivial: it just prints the secret CAS hands it. The'
printf '%s\n' 'point of the demo is *how the policy was authorised*.'
printf '%s\n' ''
printf '%s\n' '## How governance changes the flow'
printf '%s\n' ''
printf '%s\n' 'Normally `apply` signs the sessions locally (`scone session sign`). With a `remote:`'
printf '%s\n' 'block it instead:'
printf '%s\n' ''
printf '%s\n' '1. submits the assembled sessions (`POST /api/v1/signing-requests`),'
printf '%s\n' '2. waits while the signers approve,'
printf '%s\n' '3. receives the approved policies **plus their signatures**, and'
printf '%s\n' '4. builds one `SignedPolicy` per session from those signatures.'
printf '%s\n' ''
printf '%s\n' 'Governance is **SignedPolicy-only**: keep `encrypted-cas-policy: false`. An encrypted'
printf '%s\n' '(EPOL) policy under governance is rejected with a clear error.'
printf '%s\n' ''
printf '%s\n' '### The two modes'
printf '%s\n' ''
printf '%s\n' '- **Inline governance (used here)**: `remote:` **and** `access_policy:`. The sessions'
printf '%s\n' '  carry that policy and the service signs the assembled sessions.'
printf '%s\n' '- **Remote governance**: `remote:` **without** `access_policy:`. The service applies the'
printf '%s\n' '  managed policy stored for the API token, and the sessions import the access-policy'
printf '%s\n' '  config-fragment from its `cas-governance` session. That session must exist on the CAS,'
printf '%s\n' '  which the real service provides.'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- Docker, `python3`, `envsubst`, and the `scone` CLI'
printf '%s\n' '- A `scone-td-build` binary with governance support'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) if you render the templates by hand'
printf '%s\n' '- For the deploy check: a Kubernetes cluster with the SCONE stack whose CAS matches'
printf '%s\n' '  `${CAS_NAME}.${CAS_NAMESPACE}`, and a SCONE runtime version that matches that CAS'
printf '%s\n' '- A token for `registry.scontain.com` (the runtime image is pulled during sconification)'
printf '%s\n' ''
printf '%s\n' '## 2. Run both cases'
printf '%s\n' ''
printf '%s\n' 'The demo ships a **stand-in for the policy-signing service**'
printf '%s\n' '(`validate/mock_governance.py`). It is a stand-in for the *service* only: it approves'
printf '%s\n' 'automatically with a single key, but it **really signs** (it delegates to'
printf '%s\n' '`scone session sign`), so the signatures, the CAS acceptance and the attestation are all'
printf '%s\n' 'real.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'pushd governance'
printf "${RESET}"

pushd governance

printf "${VIOLET}"
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Runs the approved case and the refused case, asserting both.'
printf '%s\n' '# Add DEPLOY=1 to also deploy the confidential workload and check it attests.'
printf '%s\n' 'SCONE_TD_BUILD=${SCONE_TD_BUILD:-scone-td-build} \'
printf '%s\n' 'CAS_NAME=${CAS_NAME:-cas} CAS_NAMESPACE=${CAS_NAMESPACE:-default} \'
printf '%s\n' 'bash validate/validate.sh'
printf "${RESET}"

# Runs the approved case and the refused case, asserting both.
# Add DEPLOY=1 to also deploy the confidential workload and check it attests.
SCONE_TD_BUILD=${SCONE_TD_BUILD:-scone-td-build} \
CAS_NAME=${CAS_NAME:-cas} CAS_NAMESPACE=${CAS_NAMESPACE:-default} \
bash validate/validate.sh

printf "${VIOLET}"
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'popd'
printf "${RESET}"

popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Expected output:'
printf '%s\n' ''
printf '%s\n' '== CASE 1/2: the signers approve =='
printf '%s\n' 'PASS: 4 session(s) submitted -> 4 SignedPolicy resource(s) assembled from the signatures'
printf '%s\n' 'PASS: the confidential workload attested and received the governed secret'
printf '%s\n' '== CASE 2/2: a signer refuses (ABORTED) =='
printf '%s\n' '  ╰─▶ Governance signing request stand-in-req-1 was aborted by a signer'
printf '%s\n' 'PASS: the request was refused, apply stopped and nothing was produced to deploy'
printf '%s\n' 'ALL CASES PASSED'
printf '%s\n' ''
printf '%s\n' 'Each run uses a fresh namespace on purpose: re-running into a namespace that already has'
printf '%s\n' 'sessions makes CAS keep the ones it already stored, so a changed policy would not take'
printf '%s\n' 'effect.'
printf '%s\n' ''
printf '%s\n' '## 3. Against the real governance service'
printf '%s\n' ''
printf '%s\n' 'Point the demo at your instance instead of the stand-in and drop `validate.sh`:'
printf '%s\n' ''
printf '%s\n' 'GOVERNANCE_URL       = https://<your-policy-signing-service>'
printf '%s\n' 'GOVERNANCE_API_TOKEN = <token bound to your managed access policy>'
printf '%s\n' ''
printf '%s\n' 'Render `scone.template.yaml` with those values and run `scone-td-build apply -f manifests/scone.yaml`'
printf '%s\n' 'directly. The call then **blocks** until the real signers approve the request in the'
printf '%s\n' 'governance website, which is the production behaviour the stand-in compresses into an'
printf '%s\n' 'automatic approval. If the service uses a private CA, add `ca_cert` to the `remote:`'
printf '%s\n' 'block.'
printf '%s\n' ''
printf '%s\n' '## 4. Uninstall'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete namespace ${NAMESPACE:-governance-demo} --ignore-not-found'
printf "${RESET}"

kubectl delete namespace ${NAMESPACE:-governance-demo} --ignore-not-found

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## What is real and what is simulated'
printf '%s\n' ''
printf '%s\n' '| Real | Simulated |'
printf '%s\n' '|---|---|'
printf '%s\n' '| the sconified confidential image | the *service*: one key, automatic approval |'
printf '%s\n' '| the signatures (`scone session sign`) | the multi-signer approval workflow |'
printf '%s\n' '| CAS accepting the SignedPolicy resources | |'
printf '%s\n' '| the enclave attesting and receiving its secret | |'
printf "${RESET}"

