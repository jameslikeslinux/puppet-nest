"""Publish reviewed Nest evidence tools only; never mount live keys or deploy."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


REGISTRY = 'registry.gitlab.joyfullee.me'
REPOSITORY = REGISTRY + '/nest/config/joyride-evidence'
SOURCE = Path(__file__).resolve().parent
FILES = ('Containerfile.evidence', 'evidence_runtime.py', 'evidence_key.py',
         'installed_test_producer.py', 'installed_test_probes.py')
ENTRYPOINT = ['/opt/joyride-evidence/venv/bin/python', '-I', '-B',
              '/opt/joyride-evidence/runtime.py']


def identity(env):
    """Default-branch protected push only; no MR, tag or caller-selected target."""
    expected = {'CI_PROJECT_PATH': 'nest/config', 'CI_PROJECT_ID': '3',
                'CI_REGISTRY': REGISTRY, 'CI_COMMIT_BRANCH': 'main',
                'CI_DEFAULT_BRANCH': 'main', 'CI_COMMIT_REF_PROTECTED': 'true',
                'CI_PIPELINE_SOURCE': 'push'}
    if any(env.get(key) != value for key, value in expected.items()):
        raise ValueError('not a protected Nest main push')
    if env.get('CI_COMMIT_TAG') or env.get('EXECUTOR_ONLY') or env.get('BUILD'):
        raise ValueError('not a full reviewed source pipeline')
    sha = env.get('CI_COMMIT_SHA', '')
    if not re.fullmatch(r'[0-9a-f]{40}', sha):
        raise ValueError('invalid source head')
    numbers = [env.get(key, '') for key in ('CI_PIPELINE_ID', 'CI_JOB_ID')]
    if any(not re.fullmatch(r'[1-9][0-9]*', value) for value in numbers):
        raise ValueError('invalid pipeline identity')
    if not env.get('CI_REGISTRY_USER') or not env.get('CI_REGISTRY_PASSWORD'):
        raise ValueError('missing registry identity')
    return sha, *map(int, numbers)


def run(args, **kwargs):
    # Never echo commands, login input, registry credentials or engine stderr.
    result = subprocess.run(args, capture_output=True, text=True,
                            check=False, timeout=600, **kwargs)
    if result.returncode:
        raise RuntimeError('evidence artifact operation failed')
    return result.stdout


def publish(env, output, source=SOURCE):
    sha, pipeline, job = identity(env)
    if output.exists():
        raise ValueError('release receipt already exists')
    # Force the reviewed, committed context; untracked files never enter it.
    root = source.parents[2]
    if run(['git', '-C', str(root), 'rev-parse', 'HEAD']).strip() != sha:
        raise ValueError('checkout head mismatch')
    if run(['git', '-C', str(root), 'status', '--porcelain', '--untracked-files=no']).strip():
        raise ValueError('tracked source is modified')
    hashes = {name: hashlib.sha256((source / name).read_bytes()).hexdigest()
              for name in FILES}
    tag = f'{REPOSITORY}:{sha}-{pipeline}-{job}'
    with tempfile.TemporaryDirectory(prefix='joyride-evidence-release-') as folder:
        private = Path(folder)
        context = private / 'context'
        context.mkdir(mode=0o700)
        for name in FILES:
            (context / name).write_bytes((source / name).read_bytes())
        auth = str(private / 'auth.json')
        digestfile = private / 'digest'
        try:
            run(['podman', 'login', '--authfile', auth, '--username',
                 env['CI_REGISTRY_USER'], '--password-stdin', REGISTRY],
                input=env['CI_REGISTRY_PASSWORD'])
            run(['podman', 'build', '--authfile', auth, '--dns=172.22.4.3',
                 '--label', 'org.opencontainers.image.revision=' + sha,
                 '--label', 'org.opencontainers.image.source=https://gitlab.joyfullee.me/nest/config',
                 '--file', str(context / 'Containerfile.evidence'), '--tag', tag, str(context)])
            run(['podman', 'push', '--authfile', auth, '--digestfile', str(digestfile), tag])
            digest = digestfile.read_text().strip()
            if not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
                raise ValueError('invalid registry digest')
            immutable = REPOSITORY + '@' + digest
            # Actual registry read by digest: do not accept a local image ID/tag.
            run(['podman', 'pull', '--authfile', auth, '--policy=always', immutable])
            images = json.loads(run(['podman', 'image', 'inspect', immutable]))
            if len(images) != 1:
                raise ValueError('ambiguous registry image')
            image = images[0]
            config = image.get('Config', {})
            if (immutable not in image.get('RepoDigests', [])
                    or config.get('Labels', {}).get('org.opencontainers.image.revision') != sha
                    or config.get('Entrypoint') != ENTRYPOINT
                    or image.get('Os') != 'linux' or image.get('Architecture') != 'amd64'):
                raise ValueError('registry artifact identity mismatch')
            receipt = {'kind': 'joyride-evidence-runtime-release-v1',
                       'project_id': 3, 'project_path': 'nest/config', 'source_head': sha,
                       'pipeline_id': pipeline, 'job_id': job,
                       'image': immutable, 'digest': digest, 'platform': 'linux/amd64',
                       'source_sha256': hashes}
        finally:
            # Remove only this job's local tag; retain registry release by digest.
            # Authentication material is removed by the private directory lifetime.
            run(['podman', 'rmi', '--ignore', tag])
    with output.open('x', encoding='utf-8') as stream:
        json.dump(receipt, stream, sort_keys=True, indent=2)
        stream.write('\n')
    return receipt


def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError('expected one new receipt path')
        receipt = publish(os.environ, Path(sys.argv[1]))
        print(json.dumps(receipt, sort_keys=True))
        return 0
    except Exception:
        print('Evidence runtime publication failed; no verified release claimed.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
