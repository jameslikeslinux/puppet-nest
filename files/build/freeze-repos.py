#!/usr/bin/env python3
"""Prepare/check exact public repository inputs in an isolated build volume."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


REPOSITORIES = {
    "gentoo": "https://gitlab.joyfullee.me/nest/gentoo/portage.git",
    "nest": "https://gitlab.joyfullee.me/nest/overlay.git",
    "haskell": "https://gitlab.joyfullee.me/nest/gentoo/haskell.git",
}


def git(path, *args, allowed=(0,)):
    result = subprocess.run(
        ["git", "-C", str(path), "-c", "core.hooksPath=/dev/null", *args],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        env=dict(os.environ, GIT_OPTIONAL_LOCKS="0"),
    )
    if result.returncode not in allowed:
        raise ValueError("Git {} failed for {} (exit {})".format(args[0], path.name, result.returncode))
    return result


def root_path(value):
    path = Path(value)
    if not path.is_absolute() or path.resolve() != path or not path.is_dir():
        raise ValueError("Repository root must be an existing canonical absolute directory")
    return path


def check(root, revisions):
    if set(os.listdir(root)) != set(REPOSITORIES):
        raise ValueError("Repository inventory differs from the complete frozen selection")
    for name, url in REPOSITORIES.items():
        path = root / name
        if path.is_symlink() or not path.is_dir() or not (path / ".git").is_dir() or (path / ".git").is_symlink():
            raise ValueError("Unsafe repository directory: " + name)
        if git(path, "config", "--get", "remote.origin.url").stdout.strip() != url:
            raise ValueError("Unexpected repository origin: " + name)
        if git(path, "rev-parse", "HEAD^{commit}").stdout.strip() != revisions[name]:
            raise ValueError("Repository revision changed: " + name)
        if git(path, "symbolic-ref", "-q", "HEAD", allowed=(0, 1)).returncode != 1:
            raise ValueError("Repository is not detached: " + name)
        if any(line.startswith("160000 ") for line in git(path, "ls-files", "--stage").stdout.splitlines()):
            raise ValueError("Unmaterialized submodule input: " + name)
        if git(path, "status", "--porcelain=v1", "--untracked-files=all", "--ignored").stdout:
            raise ValueError("Repository has changed, untracked or ignored content: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("prepare", "check"))
    parser.add_argument("gentoo")
    parser.add_argument("nest")
    parser.add_argument("haskell")
    parser.add_argument("--repos-dir", default="/var/db/repos")
    args = parser.parse_args()
    revisions = {name: getattr(args, name) for name in REPOSITORIES}
    if any(re.fullmatch(r"[0-9a-f]{40}", sha) is None for sha in revisions.values()):
        raise ValueError("Every repository input must be a full lowercase Git commit SHA")
    root = root_path(args.repos_dir)
    if args.mode == "prepare":
        if os.listdir(root):
            raise ValueError("Preparation requires an empty isolated build repository volume")
        for name, url in REPOSITORIES.items():
            path = root / name
            path.mkdir()
            git(path, "init", "--quiet")
            git(path, "remote", "add", "origin", url)
            git(path, "fetch", "--quiet", "--depth=1", "origin", revisions[name])
            git(path, "checkout", "--quiet", "--detach", revisions[name])
    check(root, revisions)
    print(json.dumps({"schema": 1, "kind": "nest_build_frozen_repositories", "revisions": revisions}, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as exc:
        print("Frozen repository input refused: " + str(exc), file=sys.stderr)
        sys.exit(1)
