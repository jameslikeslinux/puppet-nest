"""Owner-scoped Podman fixtures, including GitLab's separate cancellation teardown.

Class cleanup handles partial setup and assertion failures. The CI after_script
runs independently after a terminated/killed test process; no in-process handler
can clean up after SIGKILL. Runner/host loss or force-cancel before after_script
remains outside that guarantee. Never scan by name prefix or prune the backend.
"""
import argparse
import json
import os
import re
import subprocess
import uuid

OWNER_LABEL = 'nest.joyride.fixture-owner'
INSTANCE_LABEL = 'nest.joyride.fixture-instance'
LOCAL_OWNER = 'local-' + uuid.uuid4().hex


def owner():
    if os.environ.get('CI'):
        project, job = os.environ.get('CI_PROJECT_ID', ''), os.environ.get('CI_JOB_ID', '')
        if not project.isdecimal() or not job.isdecimal():
            raise RuntimeError('CI fixture cleanup requires numeric project and job identities')
        return f'ci-{project}-{job}'
    return LOCAL_OWNER


def command(*args):
    try:
        result = subprocess.run(['podman', *args], capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f'Podman fixture {args[0]} timed out') from exc
    if result.returncode:
        # Do not dump commands, container programs, headers or environment.
        raise RuntimeError(f'Podman fixture {args[0]} failed with exit {result.returncode}')
    return result.stdout


def cleanup(scope, instance=None):
    if not re.fullmatch(r'(ci-[0-9]+-[0-9]+|local-[0-9a-f]{32})', scope):
        raise ValueError('Invalid fixture owner identity')
    labels = {OWNER_LABEL: scope}
    if instance is not None:
        if not re.fullmatch(r'[0-9a-f]{32}', instance):
            raise ValueError('Invalid fixture instance identity')
        labels[INSTANCE_LABEL] = instance
    filters = [arg for key, value in labels.items() for arg in ('--filter', f'label={key}={value}')]

    def ids(kind):
        args = ['ps', '-aq', '--no-trunc'] if kind == 'container' else ['network', 'ls', '-q', '--no-trunc']
        return command(*args, *filters).split()

    failures = []
    residue = {}
    # Retry once: a transient removal failure must not skip the upstream/network.
    for _ in range(2):
        containers = ids('container')
        if containers:
            records = json.loads(command('container', 'inspect', *containers))
            records = {row['Id']: row for row in records}
            pending = set(records)
            while pending:
                # Namespace dependents must be removed before their provider.
                providers = {records[c]['HostConfig']['NetworkMode'].removeprefix('container:')
                             for c in pending if records[c]['HostConfig']['NetworkMode'].startswith('container:')}
                leaves = pending - providers
                if not leaves:
                    raise RuntimeError('Cyclic fixture container dependencies')
                for cid in sorted(leaves):
                    row = records[cid]
                    if not all(row['Config']['Labels'].get(k) == v for k, v in labels.items()):
                        raise RuntimeError('Fixture ownership changed; refusing removal')
                    try:
                        command('rm', '-f', '--ignore', '--time', '2', cid)
                    except RuntimeError as exc:
                        failures.append(str(exc) + ': ' + cid)
                pending -= leaves
        for nid in ids('network'):
            row = json.loads(command('network', 'inspect', nid))[0]
            if not all((row.get('labels') or {}).get(k) == v for k, v in labels.items()):
                raise RuntimeError('Fixture network ownership changed; refusing removal')
            try:
                # Never force-remove an occupied network or other fixtures.
                command('network', 'rm', nid)
            except RuntimeError as exc:
                failures.append(str(exc) + ': ' + nid)
        residue = {kind: ids(kind) for kind in ('container', 'network')}
        if not any(residue.values()):
            if failures:
                print('Fixture cleanup recovered after retry: ' + '; '.join(failures))
            return
    raise RuntimeError('Fixture cleanup residue: ' + json.dumps(residue) + '; ' + '; '.join(failures))


class FixtureResources:
    def __init__(self, case):
        self.owner = owner()
        self.instance = uuid.uuid4().hex
        case.addClassCleanup(cleanup, self.owner, self.instance)

    @property
    def labels(self):
        return ('--label', f'{OWNER_LABEL}={self.owner}',
                '--label', f'{INSTANCE_LABEL}={self.instance}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['cleanup-ci'])
    parser.parse_args()
    if not os.environ.get('CI'):
        parser.error('cleanup-ci requires the current CI job identity')
    cleanup(owner())
    print('Verified no Podman fixtures remain for this CI job')
