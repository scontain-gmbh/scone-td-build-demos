# SCONE: Governance-approved CAS policy

This example shows `scone-td-build`'s **governance** flow: the generated CAS session
policies are not signed locally by whoever runs the build. They are submitted to the
**policy-signing service**, approved by the required signers, and the `SignedPolicy`
resources are assembled from the signatures the service returns.

The demo proves the approval actually gates the deployment, with two cases:

| Case | What happens |
|---|---|
| **Approved** | every session comes back signed, the CAS accepts the policies, the confidential workload attests and CAS delivers it a secret the policy grants |
| **Refused** | a signer aborts the request, `scone-td-build apply` stops with an error and **nothing is produced to deploy** |

The app (`app.py`) is deliberately trivial: it just prints the secret CAS hands it. The
point of the demo is *how the policy was authorised*.

## How governance changes the flow

Normally `apply` signs the sessions locally (`scone session sign`). With a `remote:`
block it instead:

1. submits the assembled sessions (`POST /api/v1/signing-requests`),
2. waits while the signers approve,
3. receives the approved policies **plus their signatures**, and
4. builds one `SignedPolicy` per session from those signatures.

Governance is **SignedPolicy-only**: keep `encrypted-cas-policy: false`. An encrypted
(EPOL) policy under governance is rejected with a clear error.

### The two modes

- **Inline governance (used here)**: `remote:` **and** `access_policy:`. The sessions
  carry that policy and the service signs the assembled sessions.
- **Remote governance**: `remote:` **without** `access_policy:`. The service applies the
  managed policy stored for the API token, and the sessions import the access-policy
  config-fragment from its `cas-governance` session. That session must exist on the CAS,
  which the real service provides.

## 1. Prerequisites

- Docker, `python3`, `envsubst`, and the `scone` CLI
- A `scone-td-build` binary with governance support
- `tplenv` (`cargo install tplenv`) if you render the templates by hand
- For the deploy check: a Kubernetes cluster with the SCONE stack whose CAS matches
  `${CAS_NAME}.${CAS_NAMESPACE}`, and a SCONE runtime version that matches that CAS
- A token for `registry.scontain.com` (the runtime image is pulled during sconification)

## 2. Run both cases

The demo ships a **stand-in for the policy-signing service**
(`validate/mock_governance.py`). It is a stand-in for the *service* only: it approves
automatically with a single key, but it **really signs** (it delegates to
`scone session sign`), so the signatures, the CAS acceptance and the attestation are all
real.

```bash
pushd governance
```

```bash
# Runs the approved case and the refused case, asserting both.
# Add DEPLOY=1 to also deploy the confidential workload and check it attests.
SCONE_TD_BUILD=${SCONE_TD_BUILD:-scone-td-build} \
CAS_NAME=${CAS_NAME:-cas} CAS_NAMESPACE=${CAS_NAMESPACE:-default} \
bash validate/validate.sh
```

```bash
popd
```

Expected output:

```
== CASE 1/2: the signers approve ==
PASS: 4 session(s) submitted -> 4 SignedPolicy resource(s) assembled from the signatures
PASS: the confidential workload attested and received the governed secret
== CASE 2/2: a signer refuses (ABORTED) ==
  ╰─▶ Governance signing request stand-in-req-1 was aborted by a signer
PASS: the request was refused, apply stopped and nothing was produced to deploy
ALL CASES PASSED
```

Each run uses a fresh namespace on purpose: re-running into a namespace that already has
sessions makes CAS keep the ones it already stored, so a changed policy would not take
effect.

## 3. Against the real governance service

Point the demo at your instance instead of the stand-in and drop `validate.sh`:

```
GOVERNANCE_URL       = https://<your-policy-signing-service>
GOVERNANCE_API_TOKEN = <token bound to your managed access policy>
```

Render `scone.template.yaml` with those values and run `scone-td-build apply -f manifests/scone.yaml`
directly. The call then **blocks** until the real signers approve the request in the
governance website, which is the production behaviour the stand-in compresses into an
automatic approval. If the service uses a private CA, add `ca_cert` to the `remote:`
block.

## 4. Uninstall

```bash
kubectl delete namespace ${NAMESPACE:-governance-demo} --ignore-not-found
```

## What is real and what is simulated

| Real | Simulated |
|---|---|
| the sconified confidential image | the *service*: one key, automatic approval |
| the signatures (`scone session sign`) | the multi-signer approval workflow |
| CAS accepting the SignedPolicy resources | |
| the enclave attesting and receiving its secret | |
