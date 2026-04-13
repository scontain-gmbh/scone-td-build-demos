import os
import hashlib

# Get the environment variables.
# The value of API_USER is set in the manifest and encrypted into the CAS session.
user = os.environ.get('API_USER', None)
# The value of API_PASSWORD is set in the manifest and encrypted into the CAS session.
# In a confidential SCONE deployment, the enclave protects the secret in memory.
pw = os.environ.get('API_PASSWORD', None)

if user is None or pw is None:
    print("Not all required environment variables are defined.")
    exit(1)

pw_checksum = hashlib.md5(pw.encode('utf-8')).hexdigest()

print(f"Version 2 (updated): Hello, '{user}' - software update successful!", flush=True)
print(f"The checksum of API_PASSWORD is '{pw_checksum}'", flush=True)
print("Version 2 completed successfully.", flush=True)
