#!/usr/bin/env python3
"""Local stand-in for the governance policy-signing service.

It implements the three endpoints `scone-td-build` calls, in two modes:

  approve (default)  the request is approved and every submitted session is REALLY
                     signed, by delegating to `scone session sign`. The signatures are
                     genuine, so the assembled SignedPolicy is accepted by a real CAS
                     and the confidential workload can attest.
  abort              a signer refuses the request: the status endpoint reports ABORTED,
                     `scone-td-build apply` fails, and nothing is deployed.

What is simulated is the *service* (one key, automatic approval) rather than the real
multi-signer workflow. The cryptography is real.

Usage: mock_governance.py [port]      (mode from $MOCK_MODE: approve | abort)
"""

import json
import os
import subprocess
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = os.environ.get("MOCK_MODE", "approve")

# Names bound to the API token (GET /api/v1/access-policy/names). Only used in remote
# mode; this demo runs inline governance, but the endpoint is implemented for parity.
NAMES = {
    "policy_name": "cas-governance",
    "read_any_config_fragment_name": "access_policy",
    "read_none_config_fragment_name": "access_policy_no_read",
    "cas_key": "mock-cas-key",
}

# The policy submitted by the last signing request.
SUBMITTED = {"policy": ""}


def sign_each_session(policy_blob):
    """Sign every submitted session with `scone session sign`.

    Returns the list of `{ session, signatures }` records the service would return,
    one per submitted session document.
    """
    docs = [d for d in policy_blob.split("\n---\n") if d.strip()]
    records = []
    for doc in docs:
        path = None
        try:
            with tempfile.NamedTemporaryFile(
                "w", suffix="-session.yaml", delete=False
            ) as handle:
                handle.write(doc)
                path = handle.name
            result = subprocess.run(
                ["scone", "session", "sign", path],
                capture_output=True,
                text=True,
                check=True,
            )
            records.append(json.loads(result.stdout))
        except subprocess.CalledProcessError as err:
            raise RuntimeError(
                f"`scone session sign` failed: {err.stderr.strip()}"
            ) from err
        except json.JSONDecodeError as err:
            raise RuntimeError(
                f"`scone session sign` did not return JSON: {result.stdout[:200]}"
            ) from err
        finally:
            if path:
                os.unlink(path)
    return records


class Handler(BaseHTTPRequestHandler):
    def _send(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/api/v1/access-policy/names"):
            self._send(NAMES)
            return
        if "/api/v1/signing-requests/" in self.path:
            if MODE == "abort":
                # A signer refused the request.
                self._send({"status": "ABORTED"})
                return
            try:
                self._send(sign_each_session(SUBMITTED["policy"]))
            except RuntimeError as err:
                self._send({"error": str(err)}, 500)
            return
        self._send({"error": "not found"}, 404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        if self.path.startswith("/api/v1/signing-requests"):
            try:
                SUBMITTED["policy"] = json.loads(raw).get("policy", "")
            except json.JSONDecodeError:
                SUBMITTED["policy"] = ""
            self._send({"signing_request_id": "stand-in-req-1"})
            return
        self._send({"error": "not found"}, 404)

    def log_message(self, *args):
        pass  # keep the harness output readable


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
    print(f"governance stand-in listening on 127.0.0.1:{port} (mode={MODE})", flush=True)
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
