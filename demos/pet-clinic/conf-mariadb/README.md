# Confidential MariaDB variant

This is an **optional** variant of the pet-clinic demo. Instead of the native
MariaDB, it deploys a **confidential MariaDB** (SGX, via the SCONE `mariadb-spr`
Helm chart) that the confidential PetClinic reaches through a confidential
**MaxScale** proxy over TLS.

It is adapted from SCONE's upstream `maria.sh` for our SCONE 6.x cluster:

- uses the local `scone` CLI (matches the cluster version) instead of the
  dockerised `sconecli:5.9.0`;
- uses **signed policies (`spol`)** instead of encrypted policies (`epol`), so it
  also works against the public CAS (`scone-cas.cf`) where `epol` is not
  supported yet;
- pins the newest available product images (`MARIADB_SCONE_IMAGE`, `MAXME_IMAGE`
  in `../Values.yaml`, seeded from [`../values.template.yaml`](../values.template.yaml)).

## ⚠️ Debug-only limitation

The SCONE curated MariaDB/MaxScale images are **debug-signed product images**.
They run in **SGX debug mode only**. Setting `SCONE_PRODUCTION=1` makes them
abort at start with:

```
[SCONE|FATAL] Cannot sign production enclave: no key provided
```

Unlike PetClinic (which we sconify ourselves and sign with our own
`identity.pem`), we cannot re-sign these product images for production. So this
variant is confidential but **debug-mode only**. PetClinic itself can still run
in production (see the main [README](../README.md)); the confidential MariaDB
cannot.

## Run

Configuration comes from `../Values.yaml` (seeded from
[`../values.template.yaml`](../values.template.yaml); CAS, namespace, images) —
there are no flags. `GITHUB_TOKEN` (for the `sconeappsee` repo) comes
from the environment.

```bash
export GITHUB_TOKEN=...   # and REGISTRY_USER / REGISTRY_TOKEN if the pull secret is missing
./deploy.sh              # attest CAS, create the 6 signed sessions, helm install
```

Then wire the confidential PetClinic to it by setting, in
[`../manifests/petclinic.template.yaml`](../manifests/petclinic.template.yaml):

```yaml
- name: SPRING_DATASOURCE_URL
  value: jdbc:mysql://maxscale:3306/${DB_NAME}?sslMode=REQUIRED
- name: SPRING_DATASOURCE_USERNAME
  value: root
- name: SPRING_DATASOURCE_PASSWORD
  value: "098098"
```

and run the main demo (`../README.md`, or `scripts/demos/pet-clinic.sh`). `root@%` has `ALL PRIVILEGES` (the root password
`098098` is defined in `security-policies/certificates.template.yaml`); the
`petclinic` database is created on first connection.

## How it works

`deploy.sh`:

1. adds the `sconeapps` / `sconeappsee` helm repos;
2. attests the CAS (offline for an in-cluster CAS, online for `scone-cas.cf`;
   accepted as a debug CAS with `--only_for_testing-*`);
3. for each of the 6 `security-policies/*.template.yaml`, substitutes random
   session names, then `scone session sign` + `scone session create` (spol);
4. `helm install mariadb-spr` with the images and session config IDs.

The connection model: the MaxScale client listener on `3306` is `unprotected`
(plain TLS, no client cert), so PetClinic connects with a normal MySQL TLS
handshake (`sslMode=REQUIRED`); MaxScale does the SCONE-shielded, mutually
authenticated TLS to the backend primary/replica.

## Cleanup

```bash
./delete.sh
```
