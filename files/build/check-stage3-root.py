#!/usr/bin/env python3
"""Read-only admission of one sealed versioned Stage 3 publication root."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

BASE = Path('/nest/releases')
TOKEN = r'[a-z0-9][a-z0-9._-]{0,127}'
GUID = r'[1-9][0-9]{0,19}'
DIGEST = r'sha256:[0-9a-f]{64}'


def require(condition):
    if not condition:
        raise ValueError('Stage 3 root admission failed')


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True) + '\n').encode('ascii')


def safe_ancestors(root):
    require(root.resolve(strict=True) == root)
    for path in [root, *root.parents]:
        info = path.lstat()
        require(stat.S_ISDIR(info.st_mode) and info.st_uid == 0)
        require(not info.st_mode & (stat.S_IWGRP | stat.S_IWOTH))


def observe(root, guid, release, expectations):
    # zfs list identifies a filesystem, not an arbitrary directory in its parent.
    # Do not use an input-supplied dataset name in a mutation command.
    result = subprocess.run(['zfs', 'list', '-H', '-p', '-t', 'filesystem', '-o',
                             'name,guid,mountpoint,mounted,readonly,org.nest:build-release,org.nest:expectations'],
                            capture_output=True, text=True, timeout=30, check=True)
    rows = [line.split('\t') for line in result.stdout.splitlines()]
    require(all(len(row) == 7 for row in rows))
    selected = [row for row in rows if row[2] == str(root)]
    require(len(selected) == 1)
    row = selected[0]
    require(row[1:] == [guid, str(root), 'yes', 'on', release, expectations])
    require(not any(other[0].startswith(row[0] + '/') for other in rows))
    # Also reject non-ZFS submounts and a hidden/stacked publication mount.
    mounts = []
    for line in Path('/proc/self/mountinfo').read_text().splitlines():
        before, after = line.split(' - ', 1)
        fields, filesystem = before.split(), after.split()
        path = re.sub(r'\\([0-7]{3})', lambda match: chr(int(match[1], 8)), fields[4])
        mount = Path(path)
        if mount == root or root in mount.parents:
            mounts.append((mount, filesystem[0], filesystem[1]))
    require(mounts == [(root, 'zfs', row[0])])
    return row


def metadata(info):
    return [info.st_mode, info.st_uid, info.st_gid, info.st_size,
            info.st_mtime_ns, info.st_ctime_ns, info.st_dev, info.st_ino, info.st_nlink, info.st_rdev]


def content_digest(root):
    """Hash exact bytes and restore-relevant metadata, never emit per-file hashes.

    The versioned publication is private: its root contains host key material.
    The resulting aggregate is a content identity, not a signature or permission.
    """
    digest = hashlib.sha256(b'nest-stage3-root-v1\0')
    links = {}
    device = root.lstat().st_dev

    def frame(value):
        digest.update(len(value).to_bytes(8, 'big'))
        digest.update(value)

    def visit(path, relative):
        before = path.lstat()
        require(before.st_dev == device)
        mode = before.st_mode
        require(stat.S_ISDIR(mode) or stat.S_ISREG(mode) or stat.S_ISLNK(mode)
                or stat.S_ISCHR(mode) or stat.S_ISBLK(mode) or stat.S_ISFIFO(mode))
        frame(os.fsencode(relative))
        # Inodes/device/ctime are stability checks, not transferable identities.
        frame(canonical([mode, before.st_uid, before.st_gid, before.st_mtime_ns, before.st_rdev]))
        names = sorted(os.listxattr(path, follow_symlinks=False), key=os.fsencode)
        frame(canonical([os.fsencode(name).hex() for name in names]))
        for name in names:
            frame(os.getxattr(path, name, follow_symlinks=False))
        if stat.S_ISDIR(mode):
            for name in sorted(os.listdir(path), key=os.fsencode):
                visit(path / name, relative + '/' + name)
        elif stat.S_ISLNK(mode):
            frame(os.fsencode(os.readlink(path)))
        elif stat.S_ISREG(mode):
            identity = (before.st_dev, before.st_ino)
            first = links.get(identity)
            frame(b'file' if first is None else b'hardlink')
            if first is not None:
                frame(os.fsencode(first))
            else:
                links[identity] = relative
                descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
                try:
                    require(metadata(os.fstat(descriptor)) == metadata(before))
                    frame(canonical(before.st_size))
                    total = 0
                    with os.fdopen(descriptor, 'rb', closefd=False) as stream:
                        while True:
                            chunk = stream.read(1024 * 1024)
                            if not chunk:
                                break
                            total += len(chunk)
                            digest.update(chunk)
                    require(total == before.st_size)
                    require(metadata(os.fstat(descriptor)) == metadata(before))
                finally:
                    os.close(descriptor)
        require(metadata(path.lstat()) == metadata(before))

    visit(root, '.')
    return 'sha256:' + digest.hexdigest()


def check(path, hostname, release, guid, expectations, expected_digest=None):
    for value, pattern in [(hostname, r'[a-z0-9][a-z0-9-]{0,62}'), (release, TOKEN),
                           (guid, GUID), (expectations, DIGEST)]:
        require(type(value) is str and re.fullmatch(pattern, value) is not None)
    require(expected_digest is None or re.fullmatch(DIGEST, expected_digest) is not None)
    root = BASE / release / 'hosts' / hostname
    require(type(path) is str and path == str(root))
    safe_ancestors(root)
    before = observe(root, guid, release, expectations)
    digest = content_digest(root)
    require(observe(root, guid, release, expectations) == before)
    safe_ancestors(root)
    require(expected_digest is None or digest == expected_digest)
    return {'path': str(root), 'dataset_guid': guid, 'content_digest': digest}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path')
    parser.add_argument('hostname')
    parser.add_argument('release')
    parser.add_argument('dataset_guid')
    parser.add_argument('expectations_digest')
    parser.add_argument('--content-digest')
    args = parser.parse_args()
    try:
        require(os.geteuid() == 0)
        print(json.dumps(check(args.path, args.hostname, args.release, args.dataset_guid,
                               args.expectations_digest, args.content_digest), sort_keys=True))
        return 0
    except (OSError, ValueError, TypeError, IndexError, RuntimeError, subprocess.SubprocessError):
        # Never print native errors, file names, xattrs, key bytes or traceback.
        print('Stage 3 root admission failed; no accepted root artifact emitted', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
