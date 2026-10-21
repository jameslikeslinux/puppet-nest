"""Infrastructure contract for the demonstrated Joyride host-authority gap."""
from pathlib import Path
import re
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[3]


class CiBoundaryTests(unittest.TestCase):
    def test_jobs_use_only_dedicated_rootless_engine_and_qemu(self):
        source = (ROOT / 'templates/app/joyride/ci-runner.toml.epp').read_text()
        source = re.sub(r'<%- .*? -%>\n', '', source, count=1)
        source = source.replace('<%= to_json($runner_token) %>', '"fixture-not-a-token"')
        source = re.sub(r'<% \$qemu_targets.each .*?<% } -%>\n', '', source, flags=re.S)
        runner = tomllib.loads(source)['runners'][0]
        self.assertEqual(runner['id'], 127)
        self.assertEqual(runner['docker']['host'], 'unix:///run/joyride-ci/podman.sock')
        self.assertFalse(runner['docker']['privileged'])
        self.assertEqual(runner['docker']['volumes'], [
            '/run/joyride-ci/podman.sock:/run/podman/podman.sock'])
        self.assertEqual(runner['environment'], ['CONTAINER_HOST=unix:///run/podman/podman.sock'])

    def test_engine_is_unprivileged_and_hides_operator_paths(self):
        service = (ROOT / 'files/app/joyride/joyride-ci-engine.service').read_text()
        for line in ('User=joyride-ci', 'Group=joyride-ci', 'Delegate=yes',
                     'ProtectHome=yes', 'ProtectSystem=strict', 'UMask=0077',
                     'ReadWritePaths=/var/lib/joyride-ci /run/joyride-ci'):
            self.assertIn(line + '\n', service)
        self.assertNotIn('User=root\n', service)
        self.assertNotIn('/run/podman/podman.sock', service)
        self.assertIn('InaccessiblePaths=-/etc/eyaml -/etc/puppetlabs/bolt', service)
        self.assertIn('-/etc/joyride-ci', service)
        self.assertIn('-/var/lib/joyride-evidence', service)
        self.assertIn('TemporaryFileSystem=/run/systemd:ro\n', service)
        self.assertIn('BindReadOnlyPaths=-/run/systemd/resolve\n', service)
        self.assertIn('-/run/user', service)
        self.assertNotIn('-/run/systemd ', service)

    def test_manager_custody_is_outside_engine_and_scope_is_explicit(self):
        source = (ROOT / 'manifests/service/joyride_ci.pp').read_text()
        for value in ("$scope = 'ci-runner'", "Sensitive[String]", "mode      => '0600'",
                      "show_diff => false", "backup    => false", "membership => inclusive"):
            self.assertIn(value, source)
        self.assertIn("'/etc/joyride-ci:/etc/gitlab-runner'", source)
        self.assertNotIn('/run/podman/podman.sock', source)
        self.assertNotIn('/etc/eyaml', source)
        self.assertNotIn('/etc/puppetlabs/bolt', source)
        self.assertIn('private/joyride/%{nest::service::joyride_ci::scope}.yaml',
                      (ROOT / 'hiera.yaml').read_text())

    def test_operator_subordinate_range_stays_first_and_supervisor_inactive(self):
        source = (ROOT / 'manifests/base/containers.pp').read_text()
        self.assertIn('([$nest::user] + $nest::rootless_users).unique', source)
        host = (ROOT / 'data/host/owl.yaml').read_text()
        self.assertIn("'nest::service::joyride_ci'", host)
        self.assertNotIn("'nest::service::joyride_evidence'", host)


if __name__ == '__main__':
    unittest.main()
