#!/usr/bin/env python3
"""Record/check installed executor inputs. No fetch, build, or module installation."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

IMAGE = r"[a-z0-9][a-z0-9.:-]*(?:/[a-z0-9][a-z0-9._-]*)+@sha256:[0-9a-f]{64}"


def require(value):
    if not value:
        raise ValueError("Executor input identity verification failed")


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("ascii")


def sha(payload):
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def git(directory, *args):
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
    return subprocess.check_output(["git", "-C", str(directory), *args], env=env,
                                   stderr=subprocess.DEVNULL, timeout=30).decode("ascii").rstrip("\n")


def tree(directory):
    """Bind paths, types, permission bits, bytes and link text, excluding Git internals.

    Never follow links: separately installed modules are independently enumerated.
    A link digest is not a proof that its referent is available or compatible.
    """
    rows = []
    for root, directories, files in os.walk(directory, followlinks=False):
        directories[:] = sorted(name for name in directories if name != ".git")
        for name in sorted(directories + files):
            if name == ".git":
                continue
            path = Path(root) / name
            info = path.lstat()
            mode = stat.S_IMODE(info.st_mode)
            relative = path.relative_to(directory).as_posix()
            if stat.S_ISLNK(info.st_mode):
                row = [relative, "link", os.readlink(path)]
            elif stat.S_ISDIR(info.st_mode):
                row = [relative, "directory", mode]
            else:
                require(stat.S_ISREG(info.st_mode))
                digest = hashlib.sha256()
                with path.open("rb") as stream:
                    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                        digest.update(chunk)
                row = [relative, "file", mode, "sha256:" + digest.hexdigest()]
            rows.append(row)
    require(rows)
    return sha(canonical(sorted(rows)))


def observe(project, source, base):
    require(re.fullmatch(r"[0-9a-f]{40}", source) is not None)
    require(re.fullmatch(IMAGE, base) is not None)
    require(git(project, "rev-parse", "HEAD") == source)
    require(not git(project, "status", "--porcelain", "--untracked-files=no"))
    modules = project / ".modules"
    require(modules.is_dir() and not modules.is_symlink())
    rows = []
    for module in sorted(modules.iterdir()):
        require(re.fullmatch(r"[a-z][a-z0-9_]*", module.name) is not None)
        require(module.is_dir() and not module.is_symlink())
        revision = None
        changes = ""
        if (module / ".git").exists():
            revision = git(module, "rev-parse", "HEAD")
            require(re.fullmatch(r"[0-9a-f]{40}", revision) is not None)
            changes = git(module, "status", "--porcelain", "--untracked-files=no")
            # Bolt prunes non-module files after checkout. Bind that installed
            # tree by content instead of claiming its Git worktree is pristine.
            require(all(line[:2] in (" D", "D ", "DD") for line in changes.splitlines()))
        if module.name == "nest":
            require(revision == source)
            require(not changes)
        rows.append({"name": module.name, "git_head": revision, "content_digest": tree(module)})
    require(rows and {"nest", "stdlib", "reboot", "ruby_task_helper", "private", "kubecm"}
            <= {row["name"] for row in rows})
    return {"schema": 1, "kind": "nest_config_executor_inputs", "source": source,
            "base_image": base, "puppetfile_digest": sha((project / "Puppetfile").read_bytes()),
            "modules": rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("record", "check"))
    parser.add_argument("--project", type=Path, default=Path("/opt/nest"))
    parser.add_argument("--source", required=True)
    parser.add_argument("--base", required=True)
    args = parser.parse_args()
    try:
        row = observe(args.project, args.source, args.base)
        path = args.project / ".executor-inputs.json"
        payload = canonical(row)
        if args.action == "record":
            with path.open("xb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
        require(not path.is_symlink() and path.read_bytes() == payload)
        # Only sanitized identities, never file contents, origins or environment.
        print(payload.decode("ascii"), end="")
        return 0
    except (OSError, ValueError, UnicodeError, subprocess.SubprocessError):
        print("Executor input identity verification failed", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
