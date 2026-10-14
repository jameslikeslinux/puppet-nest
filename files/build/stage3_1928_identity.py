#!/usr/bin/env python3
"""Bounded ^1928 staging preparation. Remove after this build round succeeds.

Never touches live SSL or publishes roots. All generated keys stay on Falcon.
Re-execution reuses the same isolated key/CSR; it does not clean CA records.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess

HOSTS = {
    'builder1': 'builders', 'builder2': 'builders', 'builder3': 'builders',
    'runner1': 'runners', 'control1': 'control-plane', 'control2': 'control-plane',
    'control3': 'control-plane', 'storage1': 'storage', 'storage2': 'storage',
    'storage3': 'storage', 'storage4': 'storage', 'eagle': 'eagle', 'kite': None,
    'kestrel-console': None, 'falcon-console': None, 'lark': None,
    'gateway': None, 'falcon': None, 'hawk': None, 'kestrel': None,
    'owl': None, 'osprey': None,
}
CA = '2F:38:AB:32:14:98:AB:20:9E:3C:80:54:E3:69:AB:48:DB:D5:E5:E3:0E:9C:6F:1E:4D:04:B5:5A:EF:C0:3E:6E'
ROOT = Path('/nest/stage3-1928')
SNAPSHOT = 'data/crypt/export/hosts@stage3-t_7ab83d07-before'


def run(args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'prepare_kite', 'submit', 'download', 'verify'])
    parser.add_argument('host', choices=list(HOSTS))
    args = parser.parse_args()
    assert os.geteuid() == 0, 'Requires Bolt escalation'
    assert run(['hostname', '-s']) == 'falcon', 'Falcon staging only'
    assert run(['zfs', 'list', '-H', '-o', 'name', '-t', 'snapshot', SNAPSHOT]) == SNAPSHOT
    os.umask(0o077)
    ROOT.mkdir(mode=0o700, exist_ok=True)
    assert not ROOT.is_symlink()
    with (ROOT / 'identity.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        old = Path('/nest/hosts') / args.host
        dest = ROOT / 'identities' / args.host
        conf = dest / 'etc/puppetlabs/puppet'
        ssl = conf / 'ssl'
        assert old.is_dir() and not old.is_symlink()
        assert (old / 'etc/machine-id').is_file()
        assert not dest.is_symlink()
        if args.action in ['prepare', 'prepare_kite']:
            assert (args.host == 'kite') == (args.action == 'prepare_kite'), 'Kite is import-only'
            (dest / 'etc').mkdir(parents=True, exist_ok=True)
            machine = dest / 'etc/machine-id'
            if machine.exists():
                assert machine.read_bytes() == (old / 'etc/machine-id').read_bytes()
            else:
                shutil.copy2(old / 'etc/machine-id', machine)
            conf.mkdir(parents=True, exist_ok=True)
            expected = '[main]\nserver = puppet.eyrie\nca_server = puppet.eyrie\ncertname = ' + args.host + '\n'
            sans = {'kestrel': 'kestrel,nest-ext.joyfullee.me,nest.joyfullee.me',
                    'falcon': 'falcon,falcon.home,falcon.nest,nest.james.tl'}.get(args.host)
            if sans:
                expected += 'dns_alt_names = ' + sans + '\n'
            config = conf / 'puppet.conf'
            if config.exists():
                assert config.read_text() == expected
            else:
                config.write_text(expected)
            cluster = HOSTS[args.host]
            attrs = conf / 'csr_attributes.yaml'
            expected_attrs = 'extension_requests:\n  pp_cluster: ' + cluster + '\n' if cluster else '{}\n'
            if attrs.exists():
                assert attrs.read_text() == expected_attrs
            else:
                attrs.write_text(expected_attrs)
        assert (dest / 'etc/machine-id').read_bytes() == (old / 'etc/machine-id').read_bytes()
        if args.action == 'prepare_kite':
            print(json.dumps({'host': 'kite', 'identityroot': str(dest), 'prepared_for_import': True}))
            return
        cmd = ['puppet', 'ssl', {'prepare': 'generate_request', 'submit': 'submit_request',
                               'download': 'bootstrap', 'verify': 'verify'}[args.action],
               '--confdir', str(conf), '--ssldir', str(ssl),
               '--vardir', str(ROOT / 'state' / args.host),
               '--rundir', str(ROOT / 'run' / args.host),
               '--logdir', str(ROOT / 'log' / args.host),
               '--server', 'puppet.eyrie', '--ca_server', 'puppet.eyrie',
               '--certname', args.host, '--waitforcert', '0']
        if args.action in ['prepare', 'submit']:
            assert args.host != 'kite'
            assert not (ssl / 'certs' / (args.host + '.pem')).exists(), 'Existing signed identity: verify/reuse instead'
        output = run(cmd)
        # SSL commands emit only public fingerprint/status metadata, never keys.
        print(output)
        if args.action in ['download', 'verify']:
            ca = run(['openssl', 'x509', '-in', str(ssl / 'certs/ca.pem'), '-noout', '-fingerprint', '-sha256'])
            # ca.pem may contain root first. Verify intermediate fingerprint separately.
            chain = (ssl / 'certs/ca.pem').read_text().split('-----END CERTIFICATE-----')
            fingerprints = []
            for pem in chain:
                if '-----BEGIN CERTIFICATE-----' in pem:
                    proc = subprocess.run(['openssl', 'x509', '-noout', '-fingerprint', '-sha256'],
                                          input=pem + '-----END CERTIFICATE-----\n', text=True,
                                          capture_output=True, check=True)
                    fingerprints.append(proc.stdout.strip().split('=')[-1])
            assert CA in fingerprints, 'Unexpected CA chain'
            print(run(['openssl', 'x509', '-in', str(ssl / 'certs' / (args.host + '.pem')),
                       '-noout', '-subject', '-issuer', '-fingerprint', '-sha256', '-ext', 'subjectAltName']))
        print(json.dumps({'host': args.host, 'action': args.action,
                          'identityroot': str(dest), 'rollback': SNAPSHOT,
                          'machine_id_preserved': True, 'live_ssl_modified': False}))


if __name__ == '__main__':
    main()
