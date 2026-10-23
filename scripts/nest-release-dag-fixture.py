#!/usr/bin/env python3
"""Admit only the isolated, nonpublishing native GitLab status fixture."""

import os
import sys

CONFLICTS = (
    'RELEASE_INPUTS', 'EXECUTOR_ONLY', 'BUILD', 'CPU', 'RUNNER_SMOKE_TAG',
    'RELEASE_CANDIDATE', 'RELEASE_DAG', 'RELEASE_DAG_FIXTURE',
    'RELEASE_VALIDATE_ONLY', 'RELEASE_CPU', 'RELEASE_MEMBER',
    'RELEASE_INPUT_JOB_ID', 'RELEASE_INPUT_SHA256', 'RELEASE_EXECUTOR_JOB_ID',
    'RELEASE_EXECUTOR_IMAGE', 'FROM_GENTOO', 'STAGE0_RESUME', 'REFRESH',
    'NEST_LEGACY_BUILD', 'RELEASE_PLATFORM', 'PLATFORM', 'RELEASE_VARIANT',
    'VARIANT', 'RELEASE_MODE', 'RELEASE_HOST', 'RELEASE_STAGE3_PLACEMENT_FILE',
    'HOSTNAME', 'CLUSTER', 'PROFILE',
)


def admitted(env):
    return (env.get('NEST_DAG_FIXTURE') in ('pass', 'fail', 'stage1-pass', 'stage1-fail', 'stage2-pass', 'stage2-fail', 'stage3-pass', 'stage3-fail', 'bolt-pass', 'bolt-fail') and
            env.get('CI_PIPELINE_SOURCE') in ('api', 'web') and
            not env.get('CI_COMMIT_TAG') and
            not any(env.get(key) for key in CONFLICTS))


def main():
    if sys.argv[1:] or not admitted(os.environ):
        print('Release DAG fixture selection refused; no build or deployment', file=sys.stderr)
        return 1
    print('Nonpublishing native status fixture selected; no release execution')
    return 0


if __name__ == '__main__':
    sys.exit(main())
