import os
import time
import hashlib

# Get the environment variables.
# The value of API_USER is set in the Kubernetes Secret and therefore
# visible to the administrator deploying the application.
user = os.environ.get('API_USER', None)
# The value of API_PASSWORD is stored in a Kubernetes Secret. In a
# confidential SCONE deployment, the enclave protects the secret in memory.
pw = os.environ.get('API_PASSWORD', None)
# Exit with error if either one is not defined.
if user is None or pw is None:
    print("Not all required environment variables are defined.")
    exit(1)

# We can print API_USER since it is not confidential.
print(f"Version 2 (updated): Hello, '{user}' - software update successful!", flush=True)

# We print a checksum of API_PASSWORD. After a successful update this checksum
# must match the one printed by Version 1, proving the secret was preserved.
pw_checksum = hashlib.md5(pw.encode('utf-8')).hexdigest()
print(f"The checksum of the original API_PASSWORD is '{pw_checksum}'")

while True:
    new_user = os.environ.get('API_USER', None)
    print(f"Version 2: Hello, user '{new_user}'!", flush=True)
    if new_user != user:
        print("Integrity violation: "
              f"The value of API_USER changed from '{user}' to '{new_user}'!")
        exit(1)

    new_pw = os.environ.get('API_PASSWORD', None)
    new_pw_checksum = None
    if new_pw:
        new_pw_checksum = hashlib.md5(new_pw.encode('utf-8')).hexdigest()
    print(f"The checksum of the current password is '{new_pw_checksum}'", flush=True)
    if new_pw_checksum != pw_checksum:
        print("Integrity violation: "
              f"The checksum of API_PASSWORD changed from '{pw_checksum}' to '{new_pw_checksum}'!")
        exit(1)

    print("Running Version 2.", flush=True)
    time.sleep(10)
