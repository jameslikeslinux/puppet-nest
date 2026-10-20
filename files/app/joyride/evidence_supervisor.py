"""Operator-invoked installed-TEST evidence supervisor, never an approval service.

Install only through reviewed Nest source. Application CI produces image bytes,
but cannot select this admission contract, credentials or signing invocation.
Failure preserves the private session journal; uncertain operations are not replayed.
"""
import argparse
import base64
from datetime import datetime, timezone
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tarfile
import time
import uuid

# Only independently managed sibling infrastructure code is imported.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import evidence_identity as identity

CONFIG = Path('/etc/joyride-evidence/config.json')
STATE = Path('/var/lib/joyride-evidence')
IMAGE = ('registry.gitlab.joyfullee.me/joy/joyride/joyride-evidence@sha256:'
         '3b3b3da4de283e91ec0aca5af1f89f43a55305b4ee2f960d3da50a29960ed535')
SOURCE = 'b500350d181db4a64f5f89357b8335901907fe6f'
PUBLIC = '34ddf287aeeb91f9a1c96181f0f07cbd4c37311762e8b8fe5f58ccb76d3a0a2b'
ENTRYPOINT = ['/opt/joyride-evidence/venv/bin/python', '-I', '-B', '/opt/joyride-evidence/runtime.py']
HASHES = {
    '/opt/joyride-evidence/runtime.py': '3f0a51ffef6ed2a0cc930fee82d65a50ec1cffc93e481945c8b642a6f9e63ee2',
    '/opt/joyride-evidence/source/evidence_key.py': '78a7d374983094acd0c68b152b1f0e4698cc725ccc4c8814b7e46a8a7ff0e87d',
    '/opt/joyride-evidence/source/installed_test_probes.py': '6805b60315c36a84a6f6e84984c57f6f42193833d5bd99ef1b25650befd4c24d',
    '/opt/joyride-evidence/source/installed_test_producer.py': '2332494a8e89a87286d54bae9d9e4cbcf5fc1bd0788ad077735848b799ab7610',
}
CRON = ['cronjob', 'joyride-test-delivery', '-n', 'test']


def require(value):
    if not value:
        raise ValueError('evidence_supervisor_boundary_failed')


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False).encode()


def run(args, data=None, timeout=60):
    # Never expose subprocess bodies, errors or credential-bearing commands.
    result = subprocess.run(args, input=data, capture_output=True, timeout=timeout, check=False)
    require(result.returncode == 0 and len(result.stdout) <= 8 * 1024 * 1024)
    return result.stdout


def protected(path, owner, mode, limit=65536):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        info = os.fstat(fd)
        require(stat.S_ISREG(info.st_mode) and info.st_uid == owner and info.st_nlink == 1
                and stat.S_IMODE(info.st_mode) == mode)
        data = os.read(fd, limit + 1)
        require(len(data) <= limit)
        return data
    finally:
        os.close(fd)


def check_installation():
    require(os.geteuid() != 0)
    # Config is a root-owned admission boundary, not a caller-selected file.
    for parent in [*reversed(CONFIG.parent.parents), CONFIG.parent, Path(__file__).resolve().parent]:
        info = parent.lstat()
        require(stat.S_ISDIR(info.st_mode) and info.st_uid == 0 and not info.st_mode & 0o022)
    config = json.loads(protected(CONFIG, 0, 0o644))
    require(config == {'schema': 1, 'image': IMAGE, 'source_head': SOURCE, 'public_key': PUBLIC})
    identity.private_directory(STATE)
    for name in ('signing-key.base64', 'registry.json', 'gitlab-token'):
        protected(STATE / name, os.geteuid(), 0o600)
    key = base64.b64decode(protected(STATE / 'signing-key.base64', os.geteuid(), 0o600).strip(), validate=True)
    require(len(key) == 32)
    # Derive independently with host OpenSSL, not an application import.
    public = run(['openssl', 'pkey', '-inform', 'DER', '-pubout', '-outform', 'DER'],
                 bytes.fromhex('302e020100300506032b657004220420') + key)
    require(public == bytes.fromhex('302a300506032b6570032100' + PUBLIC))
    require(json.loads(run(['podman', 'info', '--format', 'json']))['host']['security']['rootless'] is True)


def admit():
    run(['podman', 'pull', '--authfile', str(STATE / 'registry.json'), IMAGE], timeout=180)
    image = json.loads(run(['podman', 'image', 'inspect', IMAGE]))[0]
    require(image['Os'] == 'linux' and image['Architecture'] == 'amd64'
            and IMAGE in image['RepoDigests'])
    config = image['Config']
    require(config['Entrypoint'] == ENTRYPOINT and config.get('Cmd') in (None, [])
            and config['Labels']['org.opencontainers.image.revision'] == SOURCE
            and config['Labels']['org.opencontainers.image.source'] == 'https://gitlab.joyfullee.me/joy/joyride')
    container = run(['podman', 'create', '--network=none', IMAGE]).decode().strip()
    require(re.fullmatch('[0-9a-f]{64}', container))
    try:
        for path, expected in HASHES.items():
            data = run(['podman', 'cp', container + ':' + path, '-'])
            with tarfile.open(fileobj=io.BytesIO(data)) as archive:
                rows = archive.getmembers()
                require(len(rows) == 1 and rows[0].isfile() and rows[0].uid == 0
                        and not rows[0].mode & 0o022 and rows[0].size < 1048576)
                stream = archive.extractfile(rows[0])
                if stream is None:
                    raise ValueError('evidence_source_not_regular')
                require(hashlib.sha256(stream.read()).hexdigest() == expected)
    finally:
        run(['podman', 'rm', container])
    return {'image': IMAGE, 'source_head': SOURCE, 'source_sha256': HASHES}


def cron():
    return identity.command(['get', *CRON, '-o', 'json'])


def switch_cron(current, suspended):
    require(type(current['spec'].get('suspend')) is bool)
    patch = [{'op': 'test', 'path': '/metadata/uid', 'value': current['metadata']['uid']},
             {'op': 'test', 'path': '/metadata/resourceVersion', 'value': current['metadata']['resourceVersion']},
             {'op': 'test', 'path': '/spec/suspend', 'value': not suspended},
             {'op': 'replace', 'path': '/spec/suspend', 'value': suspended}]
    return identity.command(['patch', *CRON, '--type=json', '-p', json.dumps(patch), '-o', 'json'])


def quiescent(current):
    actual = cron()
    require(actual['metadata']['uid'] == current['metadata']['uid'] and actual['spec'] == current['spec']
            and actual['spec']['suspend'] is True and not actual.get('status', {}).get('active'))
    jobs = identity.command(['get', 'jobs', '-n', 'test', '-o', 'json'])['items']
    for job in jobs:
        if any(owner.get('uid') == actual['metadata']['uid'] for owner in job['metadata'].get('ownerReferences', [])):
            require(any(row.get('type') in ('Complete', 'Failed') and row.get('status') == 'True'
                        for row in job.get('status', {}).get('conditions', [])))
    journal = identity.command(['get', 'configmap', 'joyride-test-delivery-journal', '-n', 'test', '-o', 'json'])
    # Empty controller journal is the only state admitted; no rollout recovery here.
    require(journal.get('data', {}) in ({}, {'active': 'null'}))


def container_args(session, kubeconfig, signed):
    # Three narrow mounts, plus a signing-only key. No operator authority mount.
    args = ['podman', 'run', '--name', 'joyride-evidence-' + session.name, '--pull=never',
            '--read-only', '--cap-drop=ALL', '--security-opt=no-new-privileges', '--http-proxy=false',
            '--pids-limit=128', '--memory=512m', '--cpus=2', '--user', '10001:10001',
            '--tmpfs', '/scratch:rw,nosuid,nodev,noexec,size=32m,mode=1777',
            '--mount', 'type=bind,src=' + str(kubeconfig) + ',dst=/credentials/kubeconfig,ro=true',
            '--mount', 'type=bind,src=' + str(session / 'gitlab') + ',dst=/credentials/gitlab,ro=true',
            '--mount', 'type=bind,src=' + str(session / 'output') + ',dst=/output']
    if signed:
        args += ['--mount', 'type=bind,src=' + str(session / 'signing.key') + ',dst=/credentials/signing.key,ro=true']
    return args + [IMAGE, 'collect']


def verify_receipt(path, signed, pipeline, digest, head):
    data = protected(path, os.geteuid(), 0o600)
    report = json.loads(data)
    if not signed:
        require(report.get('kind') == 'unsigned-installed-test-collection'
                and 'signature' not in report and 'payload' not in report)
        payload = report['candidate']
    else:
        require(set(report) == {'payload', 'signature'})
        payload = report['payload']
    require(payload['schema'] == 1 and payload['kind'] == 'joyride-installed-test-v1'
            and payload['pipeline_url'] == 'https://gitlab.joyfullee.me/joy/joyride/-/pipelines/' + str(pipeline)
            and payload['repository'] == 'registry.gitlab.joyfullee.me/joy/joyride/app'
            and payload['digest'] == digest and payload['source_head'] == head
            and payload['namespace'] == 'test' and payload['deployment'] == 'joyride-test'
            and type(payload['observed_at']) is int and type(payload['expires_at']) is int
            and 0 <= time.time() - payload['observed_at'] < 600
            and payload['expires_at'] == payload['observed_at'] + 900
            and payload['checks'] == ['https_readiness', 'session_csrf', 'disabled_billing',
                                      'private_route_photo_gpx', 'photo_only', 'basemap_range'])
    if not signed:
        return report
    require(isinstance(report['signature'], str) and re.fullmatch('[0-9a-f]{128}', report['signature']))
    signature = bytes.fromhex(report['signature'])
    require(len(signature) == 64)
    # OpenSSL Ed25519 verification needs regular input files. Only public data.
    parent = path.parent
    identity.private_write(parent / 'verification.json', {'public_key': PUBLIC})
    for name, value in (('public.der', bytes.fromhex('302a300506032b6570032100' + PUBLIC)),
                        ('signature.bin', signature), ('message.bin', b'joyride-installed-test-v1\x00' + canonical(payload))):
        fd = os.open(parent / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(value)
    run(['openssl', 'pkeyutl', '-verify', '-pubin', '-keyform', 'DER', '-inkey', str(parent / 'public.der'),
         '-rawin', '-in', str(parent / 'message.bin'), '-sigfile', str(parent / 'signature.bin')])
    return report


def collect(pipeline, digest, head, signed):
    require(type(pipeline) is int and pipeline > 0 and re.fullmatch('sha256:[0-9a-f]{64}', digest)
            and re.fullmatch('[0-9a-f]{40}', head))
    # No replacement run while an earlier operation needs reconciliation.
    identity.private_directory(STATE / 'sessions')
    require(all((row / 'complete.json').is_file() for row in (STATE / 'sessions').iterdir()))
    session = STATE / 'sessions' / uuid.uuid4().hex
    session.mkdir(mode=0o700)
    identity.private_write(session / 'intent.json', {'schema': 1, 'pipeline': pipeline, 'digest': digest,
                                                   'source_head': head, 'signed': signed})
    before = cron()
    require(before['spec'].get('suspend') is False and before['spec']['concurrencyPolicy'] == 'Forbid')
    identity.private_write(session / 'cron-before.json', before)
    suspended = switch_cron(before, True)
    identity.private_write(session / 'cron-suspended.json', suspended)
    # A failure keeps the controller suspended and resources/journal retained.
    # Never issue an automatic retry after an uncertain create or collection.
    deadline = time.monotonic() + 90
    while True:
        try:
            quiescent(suspended)
            break
        except ValueError:
            require(time.monotonic() < deadline)
            time.sleep(2)
    pods = identity.command(['get', 'pods', '-n', 'test', '-l', 'app=joyride-test', '-o', 'json'])['items']
    pods = [row for row in pods if not row['metadata'].get('deletionTimestamp')]
    require(len(pods) == 1)
    target = identity.bind_target(pods[0]['metadata']['name'])
    require(target['image'].endswith('@' + digest))
    work = session / 'identity'
    work.mkdir(mode=0o700)
    authority = identity.Identity(work, pods[0]['metadata']['name'])
    authority.provision()
    checks = authority.verify()
    (session / 'gitlab').mkdir(mode=0o700)
    (session / 'output').mkdir(mode=0o700)
    token = protected(STATE / 'gitlab-token', os.geteuid(), 0o600).decode().strip()
    require(re.fullmatch('[A-Za-z0-9_.-]+', token))
    config = 'hosts:\n  gitlab.joyfullee.me:\n    token: ' + token + '\n    api_protocol: https\n    git_protocol: https\n'
    fd = os.open(session / 'gitlab/config.yml', os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as stream:
        stream.write(config)
    if signed:
        key = base64.b64decode(protected(STATE / 'signing-key.base64', os.geteuid(), 0o600).strip(), validate=True)
        require(len(key) == 32)
        fd = os.open(session / 'signing.key', os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(key)
    # Ordinary rootless mapping avoids keep-id's expensive image remapping.
    # Only session-local copies, not the operator files, become subordinate-owned.
    fd = os.open(session / 'kubeconfig', os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(protected(authority.config, os.geteuid(), 0o600))
    staged = [session / 'kubeconfig', session / 'gitlab', session / 'gitlab/config.yml', session / 'output']
    if signed:
        staged.append(session / 'signing.key')
    run(['podman', 'unshare', 'chown', '-h', '10001:10001', '--', *map(str, staged)])
    args = container_args(session, session / 'kubeconfig', signed)
    args += ['--pipeline', str(pipeline), '--digest', digest, '--source-head', head, '--output', '/output/receipt.json']
    args += ['--signing-key', '/credentials/signing.key'] if signed else ['--collect-only']
    identity.private_write(session / 'collection-started.json', {'container': 'joyride-evidence-' + session.name})
    run(args, timeout=660)
    # Stopped container is retained on failure for exact recovery; no second run.
    run(['podman', 'rm', 'joyride-evidence-' + session.name])
    run(['podman', 'unshare', 'chown', '-h', '0:0', '--', *map(str, staged),
         str(session / 'output/receipt.json')])
    quiescent(suspended)
    require(identity.bind_target(pods[0]['metadata']['name']) == target)
    report = verify_receipt(session / 'output/receipt.json', signed, pipeline, digest, head)
    payload = report['payload'] if signed else report['candidate']
    require(all(payload[key] == target[key] for key in ('deployment_uid', 'generation', 'delivery_id')))
    authority.revoke()
    (session / 'kubeconfig').unlink()
    (session / 'gitlab/config.yml').unlink()
    if signed:
        (session / 'signing.key').unlink()
    identity.private_write(session / 'collection-verified.json', {
        'schema': 1, 'signed': signed, 'permission_checks': checks, 'target': target,
        'receipt_sha256': hashlib.sha256(canonical(report)).hexdigest(),
        'verified_at': datetime.now(timezone.utc).isoformat()})
    current = cron()
    require(current['metadata']['uid'] == suspended['metadata']['uid'] and current['spec'] == suspended['spec'])
    switch_cron(current, False)
    require(cron()['spec']['suspend'] is False)
    identity.private_write(session / 'complete.json', {'schema': 1, 'controller_resumed': True,
                                                      'identity_revoked': True, 'signed': signed})
    return session


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('admit', 'collect', 'sign'))
    parser.add_argument('--pipeline', type=int)
    parser.add_argument('--digest')
    parser.add_argument('--source-head')
    args = parser.parse_args()
    check_installation()
    fd = os.open(STATE / 'supervisor.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as lock:
        info = os.fstat(lock.fileno())
        require(info.st_uid == os.geteuid() and info.st_nlink == 1 and stat.S_IMODE(info.st_mode) == 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        admitted = admit()
        if args.operation == 'admit':
            print(json.dumps(admitted, sort_keys=True))
        else:
            session = collect(args.pipeline, args.digest, args.source_head, args.operation == 'sign')
            print('Verified supervised collection; exact private journal: ' + str(session))


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('Evidence supervision failed; preserve exact private journal and reconcile controller/fixtures/identity before retry', file=sys.stderr)
        sys.exit(1)
