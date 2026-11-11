#!/usr/bin/env python3
"""Check the runner's host kubeconfig before a job uses it (docs/sptd-integration.md). NON_RELEASE.

  kubeconfig_guard.py PATH [--github-env FILE]

Refuses (exit 1) when PATH is missing, is a symlink, is not a regular file, is group- or
world-accessible (any of mode 0077), is not owned by the user running the job, or when its
directory (kubeconfigs/) is a symlink. The integration home itself may be a symlink: on the
VM 163 runner /srv/sptd-integration links to the state disk. The file's content is never
read or printed. With --github-env, it appends KUBECONFIG=PATH to that file ($GITHUB_ENV).
"""
import argparse
import os
import stat
import sys


def check(path):
    """Return a list of problems; empty when the file may be used."""
    if not os.path.isabs(path):
        return [f"{path} is not an absolute path"]
    parent = os.path.dirname(path)
    try:
        if stat.S_ISLNK(os.lstat(parent).st_mode):
            return [f"{parent} is a symlink"]
    except FileNotFoundError:
        return [f"{parent} does not exist"]
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return [f"{path} does not exist (run make-kubeconfig.sh on the node)"]
    if stat.S_ISLNK(info.st_mode):
        return [f"{path} is a symlink"]
    if not stat.S_ISREG(info.st_mode):
        return [f"{path} is not a regular file"]
    problems = []
    if info.st_mode & 0o077:
        problems.append(f"{path} is group- or world-accessible (mode {stat.S_IMODE(info.st_mode):04o}; needs 0600)")
    if info.st_uid != os.getuid():
        problems.append(f"{path} is not owned by the job user (uid {info.st_uid}, job uid {os.getuid()})")
    return problems


def main(argv=None):
    parser = argparse.ArgumentParser(prog="kubeconfig_guard.py", description=__doc__.splitlines()[0])
    parser.add_argument("path")
    parser.add_argument("--github-env", help="append KUBECONFIG=PATH to this file")
    args = parser.parse_args(argv)
    problems = check(args.path)
    if problems:
        print("kubeconfig refused: " + "; ".join(problems), file=sys.stderr)
        return 1
    if args.github_env:
        with open(args.github_env, "a") as handle:
            handle.write(f"KUBECONFIG={args.path}\n")
    print(f"kubeconfig {args.path}: regular file, 0600-class, owned by the job user (content not shown)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
