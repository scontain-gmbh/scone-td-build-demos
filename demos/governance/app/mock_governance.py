#!/usr/bin/env python3
"""Local stand-in for the governance policy-signing service.

It implements the three endpoints `scone-td-build` calls, in two modes:

  APPROVE (default)  the request is approved and every submitted session is REALLY
					 signed, by delegating to `scone session sign`. The signatures are
					 genuine, so the assembled SignedPolicy is accepted by a real CAS
					 and the confidential workload can attest.
  REJECT              a signer refuses the request: the status endpoint reports ABORTED,
					 `scone-td-build apply` fails, and nothing is deployed.

What is simulated is the *service* (one key, automatic approval) rather than the real
multi-signer workflow. The cryptography is real.

Usage: mock_governance.py [port]      (mode from $MOCK_MODE: APPROVE | REJECT)
"""

import json
import os
import re
import subprocess
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = os.environ.get("MOCK_POLICY_MODE", "APPROVE")
NAMESPACE = os.environ.get("NAMESPACE", "test-namespace")

# Names bound to the API token (GET /api/v1/access-policy/names). Only used in remote
# mode; this demo runs inline governance, but the endpoint is implemented for parity.
NAMES = {
	"policy_name": f"{NAMESPACE}-governance",
	"read_any_config_fragment_name": "access_policy",
	"read_none_config_fragment_name": "access_policy_no_read",
	"cas_key": "mock-cas-key",
}

# The policy submitted by the last signing request.
SUBMITTED = {"policy": ""}


def get_scone_major_version() -> int:
	"""Executes `scone --version` and extracts the major version number."""
	try:
		result = subprocess.run(
			["scone", "--version"],
			capture_output=True,
			text=True,
			check=True,
		)
		version_output = result.stdout.strip()
		match = re.search(r"(\d+)\.\d+\.\d+", version_output)
		if match:
			return int(match.group(1))
		
		match_simple = re.search(r"v?(\d+)", version_output)
		if match_simple:
			return int(match_simple.group(1))
			
		raise RuntimeError(f"Unexpected version format: {version_output!r}")
	except (subprocess.SubprocessError, FileNotFoundError) as err:
		raise RuntimeError(f"Failed to execute `scone --version`: {err}") from err


def sign_session(policy_blob: str) -> str:
	"""
	Signs session policies based on Scone CLI version:
	  - Scone v7.X: Batch signs the full policy blob in one go.
	  - Scone v6.X: Signs each document individually and joins them 
					using the ASCII record separator (\x1E) and newlines.
	"""
	major_version = get_scone_major_version()

	# --- SCONE V7.X (Batch Signing) ---
	if major_version >= 7:
		try:
			with tempfile.NamedTemporaryFile(
				mode="w", encoding="utf-8", suffix="-session.yaml", delete=True
			) as policy_file:
				policy_file.write(policy_blob)
				policy_file.flush()

				result = subprocess.run(
					["scone", "session", "sign", policy_file.name],
					capture_output=True,
					text=True,
					check=True,
				)
			return result.stdout
		except subprocess.CalledProcessError as err:
			raise RuntimeError(
				f"`scone session sign` failed: {err.stderr.strip()}"
			) from err

	# --- SCONE V6.X (Individual Signing + Record Separator Stream) ---
	else:
		docs = [d for d in policy_blob.split("\n---\n") if d.strip()]
		combined_output = []

		for doc in docs:
			path = None
			try:
				with tempfile.NamedTemporaryFile(
					mode="w", encoding="utf-8", suffix="-session.yaml", delete=False
				) as handle:
					handle.write(doc)
					handle.flush()
					path = handle.name

				result = subprocess.run(
					["scone", "session", "sign", path],
					capture_output=True,
					text=True,
					check=True,
				)
				
				res_str = result.stdout
				if res_str:
					# Matches: stdout.write_all(b"\x1E"); stdout.write_all(&res); stdout.write_all(b"\n");
					# this is the output style for v7
					combined_output.append(f"\x1E{res_str}")

			except subprocess.CalledProcessError as err:
				raise RuntimeError(
					f"`scone session sign` failed: {err.stderr.strip()}"
				) from err
			finally:
				if path and os.path.exists(path):
					os.unlink(path)

		return "".join(combined_output)

class Handler(BaseHTTPRequestHandler):
	def _send(self, obj, code=200):
		if isinstance(obj, str):
			body = obj.encode("utf-8")
		else:
			body = json.dumps(obj).encode("utf-8")
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
			if MODE == "REJECT":
				# A signer refused the request.
				self._send({"status": "ABORTED"})
				return
			try:
				self._send(sign_session(SUBMITTED["policy"]))
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
	# Bind before announcing. Printing first said "listening" while the bind
	# could still fail, so a caller waiting for that line learned nothing.
	# Port 0 asks the OS for a free one, which the caller reads back here
	# instead of assuming a fixed port nobody else is using.
	requested = int(sys.argv[1]) if len(sys.argv) > 1 else 0
	server = HTTPServer(("127.0.0.1", requested), Handler)
	print(
		f"governance stand-in listening on 127.0.0.1:{server.server_port} (mode={MODE})",
		flush=True,
	)
	server.serve_forever()
