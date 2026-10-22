#!/usr/bin/env python3
"""Disposable local path/permission fixtures; no host identity or build is touched."""

import contextlib
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "files/build/check-stage3-paths.py"
SPEC = importlib.util.spec_from_file_location("stage3_paths", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class Stage3PathsTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.identity = self.root / "identity"
        self.output = self.root / "release/hosts/fixture-host"
        self.ssl = self.identity / "etc/puppetlabs/puppet/ssl"
        for relative in ("certs", "private_keys"):
            (self.ssl / relative).mkdir(parents=True, mode=0o700)
        self.machine = self.identity / "etc/machine-id"
        self.machine.write_text("1234567890abcdef1234567890abcdef\n")
        for relative in ("certs/ca.pem", "certs/fixture-host.pem", "private_keys/fixture-host.pem"):
            path = self.ssl / relative
            path.write_text("Fixture only: deliberately not real certificate or key material\n")
            path.chmod(0o600)

    @contextlib.contextmanager
    def fixture_owners(self):
        # Model root-owned fixture files without chown/sudo or production data.
        # Actual path, type, access and mode checks still run on real local files.
        directory, file_check = CHECK.safe_directory, CHECK.safe_file
        uid, gid = os.getuid(), os.getgid()
        def fixture_directory(path, owners, groups):
            # Model a protected outer namespace. CI may place disposable test
            # storage below world-writable /tmp; that is correctly inadmissible
            # for production identity, not a reason to weaken the real checker.
            if path in self.root.parents:
                return
            directory(path, owners | {uid}, groups | {gid})
        with mock.patch.object(CHECK, "trusted_owners", return_value=({uid}, {gid})), \
                mock.patch.object(CHECK, "safe_directory", side_effect=fixture_directory), \
                mock.patch.object(CHECK, "check_tls"), \
                mock.patch.object(CHECK, "safe_file", side_effect=lambda p, u, private=False: file_check(p, u | {uid}, private)):
            yield

    def check(self, identity=None, output=None, host="fixture-host"):
        with self.fixture_owners():
            CHECK.check(str(self.identity) if identity is None else identity,
                        str(self.output) if output is None else output, host, "a" * 64)

    def test_valid_preexisting_material_is_read_only(self):
        before = {str(p): (p.lstat(), p.read_bytes() if p.is_file() else None)
                  for p in self.identity.rglob("*")}
        self.check()
        for name, (info, payload) in before.items():
            path = Path(name)
            self.assertEqual(path.lstat().st_mtime_ns, info.st_mtime_ns)
            self.assertEqual(path.lstat().st_mode, info.st_mode)
            if payload is not None:
                self.assertEqual(path.read_bytes(), payload)
        self.assertFalse(self.output.exists())

    def test_overlapping_paths_refuse_both_directions(self):
        for output in (self.identity, self.identity.parent, self.identity / "child"):
            with self.subTest(output=output), self.assertRaises(ValueError):
                self.check(output=str(output))

    def test_noncanonical_inputs_and_output_alias_refuse(self):
        alias = self.root / "alias"
        alias.symlink_to(self.identity, target_is_directory=True)
        for identity in (str(alias), str(self.identity) + "/", str(self.identity) + "/../identity", "relative"):
            with self.subTest(identity=identity), self.assertRaises(ValueError):
                self.check(identity=identity)
        with self.assertRaises(ValueError):
            self.check(output=str(alias / "not-created"))

    def test_missing_identity_is_not_created(self):
        with self.assertRaises(OSError):
            self.check(identity=str(self.root / "absent"))
        self.assertFalse((self.root / "absent").exists())

    def test_dangling_output_link_and_ssl_directory_link_refuse(self):
        alias = self.root / "dangling"
        alias.symlink_to(self.root / "absent", target_is_directory=True)
        with self.assertRaises(ValueError):
            self.check(output=str(alias / "nested"))
        (self.ssl / "extra-directory").symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.check()

    def test_directory_walk_failure_is_not_silently_ignored(self):
        def unreadable(*args, **kwargs):
            kwargs["onerror"](PermissionError("fixture only"))
        with mock.patch.object(CHECK.os, "walk", side_effect=unreadable), self.assertRaises(PermissionError):
            self.check()

    def test_machine_identity_is_required_and_not_generated(self):
        for value in ("", "uninitialized\n", "0" * 32, "A" * 32, "a" * 32 + "\nextra"):
            self.machine.write_text(value)
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.check()
            self.assertEqual(self.machine.read_text(), value)

    def test_missing_host_key_or_ca_refuses(self):
        for relative in ("certs/ca.pem", "certs/fixture-host.pem", "private_keys/fixture-host.pem"):
            path = self.ssl / relative
            data = path.read_bytes()
            path.unlink()
            with self.subTest(relative=relative), self.assertRaises(OSError):
                self.check()
            path.write_bytes(data)
            path.chmod(0o600)

    def test_untrusted_owner_and_group_are_rejected(self):
        with self.assertRaises(ValueError):
            CHECK.safe_directory(self.identity, {os.getuid() + 1}, {os.getgid()})
        self.identity.chmod(0o770)
        with self.assertRaises(ValueError):
            CHECK.safe_directory(self.identity, {os.getuid()}, {os.getgid() + 1})
        with self.assertRaises(ValueError):
            CHECK.safe_file(self.machine, {os.getuid() + 1})

    def test_writable_directory_or_public_private_key_refuses(self):
        self.identity.chmod(0o777)
        with self.assertRaises(ValueError):
            self.check()
        self.identity.chmod(0o700)
        key = self.ssl / "private_keys/fixture-host.pem"
        for mode in (0o640, 0o604, 0o620, 0o602):
            key.chmod(mode)
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                self.check()

    def test_extra_symlink_fifo_or_writable_file_in_ssl_refuses(self):
        extra = self.ssl / "extra"
        for kind in ("link", "fifo", "writable"):
            if kind == "link":
                extra.symlink_to(self.machine)
            elif kind == "fifo":
                os.mkfifo(extra)
            else:
                extra.write_text("fixture")
                extra.chmod(0o666)
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                self.check()
            extra.unlink()

    def test_wrong_hostname_empty_and_oversized_material_refuse(self):
        with self.assertRaises(OSError):
            self.check(host="another-host")
        with self.assertRaises(ValueError):
            self.check(host="../fixture-host")
        key = self.ssl / "private_keys/fixture-host.pem"
        for payload in (b"", b"x" * (1024 * 1024 + 1)):
            key.write_bytes(payload)
            with self.assertRaises(ValueError):
                self.check()

    def test_cli_failure_is_sanitized_and_does_not_create_paths(self):
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.root / "secret-source"),
                                 str(self.output), "fixture-host", "a" * 64], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "Stage 3 identity/path admission failed\n")
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
