#!/usr/bin/env python3
"""Read-only runtime release/publication metadata admission on the supervisor."""

import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location('release_manifest', Path(__file__).resolve().parents[1] / 'scripts/nest-release-manifest.py')
assert SPEC is not None and SPEC.loader is not None
RELEASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RELEASE)


def main():
    try:
        raw = sys.stdin.buffer.read(RELEASE.LIMIT + 1)
        RELEASE.require(len(raw) <= RELEASE.LIMIT, 'Oversized input')
        params = json.loads(raw, object_pairs_hook=RELEASE.unique_object, parse_int=RELEASE.json_integer,
                            parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
        RELEASE.require(type(params) is dict and {'manifest', 'policies'} <= set(params)
                        and all(key in {'manifest', 'policies', 'scope'} or key.startswith('_') for key in params), 'Invalid parameters')
        result = RELEASE.generation_binding(params['manifest'], params['policies'], params.get('scope'))
        print(RELEASE.canonical(result).decode('ascii'), end='')
        return 0
    except (OSError, ValueError, TypeError, KeyError, UnicodeError, RecursionError):
        print(json.dumps({'_error': {'kind': 'nest/update-generation-binding',
                                    'msg': 'Generation does not bind the complete release manifest and selected scope; no host action performed'}}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
