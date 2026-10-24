#!/usr/bin/env python3
"""Retain a bound public backup observation, never a backup payload or lease."""

from datetime import datetime
import hashlib
import json
import sys
from typing import Any

sys.dont_write_bytecode = True
from retain_update_report import output_directory, publish_document, require, token
from update_wave_plan import backup_requirements, fields, unique_object


def binding(check, retention):
    fields(retention, 'transaction release hostname policy_sha256 stage output_dir')
    hostname = token(retention['hostname'], r'[a-z0-9][a-z0-9_.-]{0,127}')
    backup_requirements({hostname: [check]}, [hostname])
    token(retention['transaction'], r'[A-Za-z0-9][A-Za-z0-9_-]{0,63}')
    token(retention['release'], r'sha256:[0-9a-f]{64}')
    token(retention['policy_sha256'], r'[0-9a-f]{64}')
    require(retention['stage'] in ('preflight', 'initiation'), 'Invalid observation stage')
    output_directory(retention['output_dir'])


def timestamp(value):
    token(value, r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z')
    return datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ')


def project(raw, check, retention):
    binding(check, retention)
    require(type(raw) is str and len(raw.encode('utf-8')) <= 65536, 'Invalid observation size')
    row: Any = json.loads(raw, object_pairs_hook=unique_object)
    require(type(row) is dict and type(row.get('schema')) is int and row['schema'] == 1
            and row.get('kind') == 'nest_hermes_generation_verification' and row.get('action') == 'verified',
            'Invalid native verification outcome')
    require(row.get('restore_verified') is False and row.get('execution_authorized') is False,
            'Unexpected native authority')
    require(row.get('checkpoint') == check['checkpoint'] and row.get('sha256') == check['expected_sha256']
            and row.get('archive') == 'hermes-home-' + check['checkpoint'] + '.zip', 'Wrong generation')
    require(type(row.get('max_age_seconds')) is int and row['max_age_seconds'] == check['max_age_seconds']
            and row.get('required_profiles') == check['required_profiles'], 'Wrong verification requirements')
    for key in ('bytes', 'members'):
        require(type(row.get(key)) is int and 0 < row[key] <= 9223372036854775807, 'Invalid archive counts')
    age = (timestamp(row['checked_at']) - timestamp(row['created_at'])).total_seconds()
    require(0 <= age <= check['max_age_seconds'], 'Inconsistent publication age')
    # Bind the placement without copying account paths into the public report.
    # This is the requested inventory identity, not independent remote identity.
    check_digest = hashlib.sha256((json.dumps(check, sort_keys=True, separators=(',', ':')) + '\n').encode('ascii')).hexdigest()
    return {
        'schema': 1, 'kind': 'nest_update_backup_verification',
        **{key: retention[key] for key in ('transaction', 'release', 'hostname', 'policy_sha256', 'stage')},
        'backup_target': check['target'], 'requirement_sha256': check_digest,
        'verification': {key: row[key] for key in ('checkpoint', 'sha256', 'bytes', 'members', 'required_profiles',
                                                 'created_at', 'checked_at', 'max_age_seconds')},
        'verification_retained': True, 'retention_lease': False, 'restore_verified': False,
        'execution_authorized': False, 'transport_sha256': hashlib.sha256(raw.encode('utf-8')).hexdigest(),
    }


def main():
    try:
        raw = sys.stdin.buffer.read(262145)
        require(len(raw) <= 262144, 'Input too large')
        params = json.loads(raw, object_pairs_hook=unique_object)
        check, retention = params['check'], params['retention']
        binding(check, retention)
        action = params.get('action', 'retain')
        require(action in ('check', 'retain'), 'Invalid action')
        if action == 'check':
            print(json.dumps({'destination_checked': True, 'host_action_performed': False}))
            return 0
        report = project(params['report'], check, retention)
        prefix = retention['hostname'] + '-' + retention['transaction'] + '-backup-' + retention['stage']
        receipt = publish_document(report, retention['output_dir'], prefix)
        print(json.dumps(dict(receipt, verification_retained=True, retention_lease=False, restore_verified=False)))
        return 0
    except (KeyError, TypeError, ValueError, OSError, UnicodeError, RecursionError, OverflowError):
        print(json.dumps({'_error': {'kind': 'nest/update-backup-retention',
                                   'msg': 'Backup observation validation or supervisor retention failed'}}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
