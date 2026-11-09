#!/usr/bin/env python3
"""Minimal app for the governance demo.

The app itself is deliberately trivial: the point of this demo is *how its CAS
session policy is authorised*. Instead of being signed locally by a single key,
the policy is submitted to the governance policy-signing service, approved by the
required signers, and the SignedPolicy is assembled from those collected
signatures. This process just proves the confidential workload starts under that
governance-approved policy and can read a secret the policy grants it.
"""

import os
import time

# `governed_secret` is provisioned to the enclave by CAS only if the workload
# attests successfully under the governance-approved session policy.
SECRET = os.environ.get("GOVERNED_SECRET", "(secret not provisioned)")
INTERVAL = float(os.environ.get("INTERVAL_SECONDS", "5"))


def main():
    print("[governance-demo] started under a governance-approved policy", flush=True)
    while True:
        print(f"[governance-demo] governed secret = {SECRET}", flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
