#!/usr/bin/env python3
"""Restricted TEST logical generations; local staging, final-copy publication only."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid


class BackupError(Exception):
    pass


# Hash names and bytes without logging private paths. Refuse special files and
# symlinks, including directory symlinks; a capture must not escape these roots.
SCAN = '''import hashlib,json,os,stat
from pathlib import Path
root=Path('/data'); result={}
for name in ('private','public','maps'):
 p=root/name
 if not p.is_dir() or p.is_symlink(): raise RuntimeError('missing_root')
 for current,dirs,files in os.walk(p,followlinks=False):
  for entry in dirs+files:
   q=Path(current)/entry; mode=q.lstat().st_mode
   if stat.S_ISDIR(mode): continue
   if not stat.S_ISREG(mode): raise RuntimeError('special_file')
   with q.open('rb') as f: digest=hashlib.file_digest(f,'sha256').hexdigest()
   result[str(q.relative_to(root))]=digest
print(json.dumps(result,sort_keys=True))
'''
ARCHIVE = '''import sys,tarfile
with tarfile.open(fileobj=sys.stdout.buffer,mode='w|') as archive:
 for name in ('private','public','maps'): archive.add('/data/'+name,arcname=name)
'''


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def command(args, output=None, data=None):
    # Never forward private subprocess output or exception messages to Job logs.
    result = subprocess.run(args, input=data, stdout=output or subprocess.PIPE,
                            stderr=subprocess.DEVNULL, timeout=1200, check=False)
    if result.returncode:
        raise BackupError('capture_command_failed')
    return result.stdout


def kube(*args, output=None, data=None):
    return command(['kubectl', '--request-timeout=60s', '-n', 'test', *args], output, data)


def select_pod(selector):
    pods = json.loads(kube('get', 'pods', '-l', selector, '-o', 'json'))['items']
    ready = [p for p in pods if not p['metadata'].get('deletionTimestamp')
             and any(c['type'] == 'Ready' and c['status'] == 'True'
                     for c in p.get('status', {}).get('conditions', []))]
    if len(ready) != 1:
        raise BackupError('ambiguous_ready_pod')
    return ready[0]


def app(pod, code):
    return kube('exec', pod['metadata']['name'], '-c', 'web', '--', 'python', '-c', code)


def verify_files(path, expected):
    actual = {}
    with tarfile.open(path) as archive:
        for entry in archive:
            name = entry.name
            if name.startswith('/') or '..' in Path(name).parts or name.split('/')[0] not in ('private', 'public', 'maps'):
                raise BackupError('unsafe_archive_path')
            if entry.isdir():
                continue
            if not entry.isfile() or name in actual:
                raise BackupError('unsafe_archive_member')
            with archive.extractfile(entry) as stream:
                actual[name] = hashlib.file_digest(stream, 'sha256').hexdigest()
    if actual != expected:
        raise BackupError('files_changed_during_capture')


def publish(payload, destination, metadata):
    """A final archive is restorable only with valid matching completion JSON.

    No working directory, .tmp copy or payload construction on the backup mount.
    Copy the completed local archive to its permanent exclusive name, fsync and
    rehash it there, then commit its small completion record. A killed copy can
    leave an uncommitted final file; restore discovery MUST ignore such files.
    Never replace a previous generation or delete a known-good generation.
    """
    name = time.strftime('%Y%m%dT%H%M%SZ', time.gmtime()) + '-' + uuid.uuid4().hex
    target = destination / (name + '.tar')
    receipt = destination / (name + '.complete.json')
    expected = sha256(payload)
    created_target = False
    created_receipt = False
    try:
        with target.open('xb') as out:
            created_target = True
            os.chmod(target, 0o600)
            with payload.open('rb') as source:
                shutil.copyfileobj(source, out, 1024 * 1024)
            out.flush()
            os.fsync(out.fileno())
        if sha256(target) != expected:
            raise BackupError('publication_readback_failed')
        record = {**metadata, 'archive': target.name, 'sha256': expected,
                  'bytes': target.stat().st_size, 'complete': True}
        with receipt.open('x') as out:
            created_receipt = True
            os.chmod(receipt, 0o600)
            json.dump(record, out, sort_keys=True)
            out.flush()
            os.fsync(out.fileno())
        if json.loads(receipt.read_text()) != record:
            raise BackupError('receipt_readback_failed')
        fd = os.open(destination, os.O_DIRECTORY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    except BaseException:
        if created_receipt:
            receipt.unlink(missing_ok=True)
        if created_target:
            target.unlink(missing_ok=True)
        raise
    return record


def backup(stage_root, destination):
    os.umask(0o077)
    stage_root = stage_root.resolve()
    destination = destination.resolve()
    if (stage_root == destination or destination in stage_root.parents
            or stage_root == Path('/nest/backup') or Path('/nest/backup') in stage_root.parents):
        raise BackupError('staging_must_be_local')
    destination.mkdir(parents=True, mode=0o700, exist_ok=True)
    destination.chmod(0o700)
    with (destination / '.backup.lock').open('a+b') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        pod = select_pod('app=joyride-test')
        primary = select_pod('cnpg.io/cluster=joyride-test-cnpg,cnpg.io/instanceRole=primary')
        before = json.loads(app(pod, SCAN))
        with tempfile.TemporaryDirectory(prefix='joyride-', dir=stage_root) as temporary:
            stage = Path(temporary)
            dump = stage / 'database.dump'
            with dump.open('wb') as out:
                kube('exec', primary['metadata']['name'], '-c', 'postgres', '--',
                     'pg_dump', '-U', 'postgres', '-d', 'joyride', '--format=custom', output=out)
            # A real PostgreSQL archive parser, not just a magic-byte check.
            with dump.open('rb') as source:
                result = subprocess.run(['kubectl', '--request-timeout=60s', '-n', 'test', 'exec', '-i',
                                         primary['metadata']['name'], '-c', 'postgres', '--', 'pg_restore', '--list'],
                                        stdin=source, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1200)
                if result.returncode:
                    raise BackupError('database_archive_invalid')
            files = stage / 'files.tar'
            with files.open('wb') as out:
                kube('exec', pod['metadata']['name'], '-c', 'web', '--', 'python', '-c', ARCHIVE, output=out)
            verify_files(files, before)
            if json.loads(app(pod, SCAN)) != before:
                raise BackupError('files_changed_during_capture')
            current = select_pod('app=joyride-test')
            if current['metadata']['uid'] != pod['metadata']['uid']:
                raise BackupError('application_replaced_during_capture')
            metadata = {'schema': 1, 'environment': 'test', 'created_at': int(time.time()),
                        'images': {c['name']: c['image'] for c in pod['spec']['containers']},
                        'database_sha256': sha256(dump), 'files_sha256': sha256(files),
                        'file_count': len(before), 'consistency': 'database_snapshot_with_stable_files'}
            (stage / 'metadata.json').write_text(json.dumps(metadata, sort_keys=True))
            payload = stage / 'generation.tar'
            with tarfile.open(payload, 'w') as archive:
                for name in ('database.dump', 'files.tar', 'metadata.json'):
                    archive.add(stage / name, arcname=name)
            return publish(payload, destination, metadata)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage-root', type=Path, required=True)
    # Deliberately fixed TEST target; this helper cannot back up or restore prod.
    args = parser.parse_args()
    try:
        record = backup(args.stage_root, Path('/nest/backup/joyride-test'))
        print(json.dumps({'backup': 'complete', 'archive': record['archive'], 'sha256': record['sha256']}))
    except Exception:
        print('Joyride TEST backup failed; previous completed generations retained', file=sys.stderr)
        sys.exit(1)
