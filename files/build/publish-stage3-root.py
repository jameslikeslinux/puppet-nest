#!/usr/bin/env python3
"""Copy a sealed local build tree into a new private versioned ZFS root."""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

SPEC = importlib.util.spec_from_file_location('stage3_root', Path(__file__).with_name('check-stage3-root.py'))
assert SPEC is not None and SPEC.loader is not None
ROOT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ROOT)
require = ROOT.require


def command(arguments):
    # Never forward paths, private rsync diagnostics or ZFS stderr to CI logs.
    return subprocess.run(arguments, capture_output=True, text=True, timeout=3600, check=True).stdout


def filesystem(path, readonly, guid=None, parent=False):
    output = command(['zfs', 'list', '-H', '-p', '-t', 'filesystem', '-o', 'name,guid,mountpoint,mounted,readonly'])
    rows = [line.split('\t') for line in output.splitlines()]
    require(all(len(row) == 5 for row in rows))
    selected = [row for row in rows if row[2] == str(path)]
    require(len(selected) == 1)
    row = selected[0]
    require(re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.:/-]*', row[0]) is not None)
    require(re.fullmatch(ROOT.GUID, row[1]) is not None)
    require(row[3:] == ['yes', readonly] and (guid is None or row[1] == guid))
    if not parent:
        require(not any(other[0].startswith(row[0] + '/') for other in rows))
    mounts = []
    for line in Path('/proc/self/mountinfo').read_text().splitlines():
        before, after = line.split(' - ', 1)
        fields, filesystem_fields = before.split(), after.split()
        mount = Path(re.sub(r'\\([0-7]{3})', lambda match: chr(int(match[1], 8)), fields[4]))
        if mount == path or (not parent and path in mount.parents):
            mounts.append((mount, filesystem_fields[0], filesystem_fields[1]))
    require(mounts == [(path, 'zfs', row[0])])
    ROOT.safe_ancestors(path)
    return row


def fsync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def publish(source, hostname, release, parent_guid, expectations):
    require(os.geteuid() == 0)
    for value, pattern in [(hostname, r'[a-z0-9][a-z0-9-]{0,62}'), (release, ROOT.TOKEN),
                           (parent_guid, ROOT.GUID), (expectations, ROOT.DIGEST)]:
        require(type(value) is str and re.fullmatch(pattern, value) is not None)
    source = Path(source)
    parent = ROOT.BASE / release / 'hosts'
    destination = parent / hostname
    require(source.is_absolute() and source != Path('/') and source.resolve(strict=True) == source)
    require(source != ROOT.BASE and source not in ROOT.BASE.parents and ROOT.BASE not in source.parents)
    # A separate preprovisioned parent is the storage/capacity/placement boundary.
    # This command never chooses a pool, creates ancestors or relaxes a quota.
    parent_row = filesystem(parent, 'off', parent_guid, parent=True)
    require(stat.S_IMODE(parent.stat().st_mode) == 0o700)
    source_row = filesystem(source, 'on')
    require(source_row[0] != parent_row[0] and not parent_row[0].startswith(source_row[0] + '/'))
    source_digest = ROOT.content_digest(source)
    require(filesystem(source, 'on') == source_row)
    dataset = parent_row[0] + '/' + hostname
    # mkdir is the no-clobber reservation, including after failure or interruption.
    # Never remove it or destroy an incomplete dataset to make a retry fit.
    destination.mkdir(mode=0o700)
    fsync_directory(parent)
    require(filesystem(parent, 'off', parent_guid, parent=True) == parent_row)
    command(['zfs', 'create', '-u', '-o', 'mountpoint=' + str(destination),
             '-o', 'canmount=noauto', '-o', 'readonly=off', '-o', 'exec=off',
             '-o', 'setuid=off', '-o', 'devices=off',
             '-o', 'org.nest:build-release=' + release,
             '-o', 'org.nest:expectations=' + expectations, dataset])
    command(['zfs', 'mount', dataset])
    created = filesystem(destination, 'off')
    require(created[0] == dataset)
    require(filesystem(source, 'on') == source_row)
    # The source is a completed offline root filesystem, not / or an NFS share.
    # Copy everything: no implicit exclusion can hide a missing mounted subtree.
    command(['rsync', '--archive', '--acls', '--hard-links', '--xattrs', '--numeric-ids',
             '--modify-window=-1', '--one-file-system', '--', str(source) + '/', str(destination) + '/'])
    require(filesystem(source, 'on') == source_row)
    require(ROOT.content_digest(source) == source_digest)
    require(filesystem(destination, 'off', created[1]) == created)
    # Flush copied data before sealing; zpool sync is not a snapshot or reserve.
    command(['zpool', 'sync', dataset.split('/')[0]])
    command(['zfs', 'set', 'readonly=on', dataset])
    # Native properties, mount closure and full copied identity must independently
    # pass the existing admission primitive; command exit zero alone is not enough.
    result = ROOT.check(str(destination), hostname, release, created[1], expectations, source_digest)
    require(filesystem(source, 'on') == source_row)
    require(filesystem(parent, 'off', parent_guid, parent=True) == parent_row)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source')
    parser.add_argument('hostname')
    parser.add_argument('release')
    parser.add_argument('parent_guid')
    parser.add_argument('expectations_digest')
    args = parser.parse_args()
    try:
        print(json.dumps(publish(args.source, args.hostname, args.release, args.parent_guid,
                                 args.expectations_digest), sort_keys=True))
        return 0
    except (OSError, ValueError, TypeError, IndexError, RuntimeError, subprocess.SubprocessError):
        print('Stage 3 root publication failed; retain reserved paths for diagnosis; no accepted artifact emitted', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
