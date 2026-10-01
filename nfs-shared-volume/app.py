#!/usr/bin/env python3
"""Tiny shared-file app for the NFS-backed shared-volume demo.

The same image runs in two roles, selected by the ROLE env var:

  * ROLE=writer  -> appends a timestamped line to the shared file every few
                    seconds.
  * ROLE=reader  -> reads the shared file every few seconds and prints how many
                    lines it sees and the most recent one.

Both roles mount the *same* volume at /data. When two pods share one
PersistentVolumeClaim, scone-td-build re-shares it over NFS, so the reader ends
up seeing exactly what the writer wrote, through the NFS export.
"""

import datetime
import os
import time

ROLE = os.environ.get("ROLE", "reader")
SHARED_FILE = os.environ.get("SHARED_FILE", "/data/shared.log")
INTERVAL = float(os.environ.get("INTERVAL_SECONDS", "3"))


def run_writer():
    counter = 0
    while True:
        counter += 1
        stamp = datetime.datetime.utcnow().isoformat()
        line = f"{stamp}Z writer message #{counter}"
        with open(SHARED_FILE, "a", encoding="utf-8") as handle:
            handle.write(line + "\n")
        print(f"[writer] wrote: {line}", flush=True)
        time.sleep(INTERVAL)


def run_reader():
    while True:
        try:
            with open(SHARED_FILE, encoding="utf-8") as handle:
                lines = handle.read().splitlines()
            last = lines[-1] if lines else "(empty)"
            print(f"[reader] {len(lines)} line(s) so far; last: {last}", flush=True)
        except FileNotFoundError:
            print("[reader] shared file not created by the writer yet...", flush=True)
        time.sleep(INTERVAL)


def main():
    print(f"[{ROLE}] starting; shared file = {SHARED_FILE}", flush=True)
    if ROLE == "writer":
        run_writer()
    else:
        run_reader()


if __name__ == "__main__":
    main()
