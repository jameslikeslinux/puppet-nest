#!/usr/bin/env python3
"""Bind read-only native status commands to an exact complete wave policy."""

import json
import sys
from typing import Any

sys.dont_write_bytecode = True
from update_wave_plan import LIMIT, canonical, fields, plan, require, token, unique_object


def observe(policy: Any, targets: Any, inputs: Any):
    result = plan(policy, targets)
    require(type(inputs) is dict and set(inputs) == {host['name'] for host in policy['hosts']})
    commands = {}
    for name, entry in inputs.items():
        fields(entry, 'transaction')
        transaction = token(entry['transaction'], r'[A-Za-z0-9][A-Za-z0-9_-]{0,63}')
        commands[name] = ['nest', 'reset', 'status', transaction, '--format=json']
    return dict(result, kind='nest_update_observe_inputs', inputs=inputs, commands=commands)


def main():
    try:
        raw = sys.stdin.buffer.read(LIMIT + 1)
        require(len(raw) <= LIMIT)
        params: Any = json.loads(raw, object_pairs_hook=unique_object)
        require(type(params) is dict and {'policy', 'targets', 'inputs'} <= set(params)
                and all(key in {'policy', 'targets', 'inputs'} or key.startswith('_') for key in params))
        print(canonical(observe(params['policy'], params['targets'], params['inputs'])).decode('ascii'), end='')
        return 0
    except (KeyError, TypeError, ValueError, UnicodeError, RecursionError):
        print(json.dumps({'_error': {'kind': 'nest/update-observe-inputs',
                                    'msg': 'Invalid complete observation inputs; no host action performed'}}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
