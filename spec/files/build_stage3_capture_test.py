#!/usr/bin/env python3
"""Stable private capture and disposable install fixtures, never deployed identity."""

import contextlib
import importlib.util
import io
from pathlib import Path
import sys
from unittest import mock
import unittest

SPEC = importlib.util.spec_from_file_location("trust_fixtures", Path(__file__).with_name("build_stage3_trust_test.py"))
assert SPEC is not None and SPEC.loader is not None
TRUST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TRUST)
CHECK = TRUST.CHECK


class Stage3CaptureTest(TRUST.Stage3TrustTest):
    def capture(self):
        with self.fixture_namespace():
            return CHECK.capture(str(self.identity), str(self.output), "fixture-host", self.pin)

    def destination(self):
        destination = self.root / "build-root"
        puppet = destination / "etc/puppetlabs/puppet"
        (puppet / "ssl").mkdir(parents=True)
        (puppet / "ssl/old-only").write_text("old fixture")
        (destination / "etc/machine-id").write_text("old fixture machine\n")
        return destination

    def install(self, inventory, material, destination):
        with self.fixture_namespace():
            CHECK.install_capture(inventory, material, destination)
        self.assertEqual(list((destination / "etc/puppetlabs/puppet").glob(".nest-stage3-identity-*")), [])

    def test_install_uses_captured_bytes_after_source_removal(self):
        (self.ssl / "empty").mkdir()
        inventory, material = self.capture()
        import shutil
        shutil.rmtree(self.identity)
        destination = self.destination()
        self.install(inventory, material, destination)
        for relative, value in material.items():
            self.assertEqual((destination / relative).read_bytes(), value)
            self.assertEqual((destination / relative).stat().st_mode, inventory[relative][3])
        self.assertTrue((destination / "etc/puppetlabs/puppet/ssl/empty").is_dir())
        self.assertFalse((destination / "etc/puppetlabs/puppet/ssl/old-only").exists())
        self.assertFalse(self.output.exists())

    def test_source_rewrite_during_capture_refuses_before_install(self):
        original = CHECK.read_material
        def changing(path):
            value = original(path)
            if path == self.identity / "etc/machine-id":
                path.write_bytes(b"f" * 32 + b"\n")
            return value
        with mock.patch.object(CHECK, "read_material", side_effect=changing), self.assertRaises(ValueError):
            self.capture()
        self.assertFalse(self.output.exists())

    def test_add_or_remove_during_capture_refuses(self):
        original = CHECK.read_material
        for remove in (False, True):
            extra = self.ssl / "fixture-extra"
            extra.write_text("fixture")
            extra.chmod(0o600)
            def changing(path):
                value = original(path)
                if path == self.identity / "etc/machine-id":
                    if remove:
                        extra.unlink()
                    else:
                        (self.ssl / "new-directory").mkdir(exist_ok=True)
                return value
            with self.subTest(remove=remove), mock.patch.object(CHECK, "read_material", side_effect=changing), self.assertRaises((OSError, ValueError)):
                self.capture()

    def test_captured_material_is_cryptographically_checked(self):
        original = CHECK.read_material
        def wrong_key(path):
            if path == self.key:
                return (self.fixtures / "wrong-host.key").read_bytes()
            return original(path)
        # Path admission uses the same injected reader too; neither path can
        # accept a mismatched key. No destination has been opened at refusal.
        with mock.patch.object(CHECK, "read_material", side_effect=wrong_key), self.assertRaises(ValueError):
            self.capture()

    def test_staging_failure_keeps_destination_and_cleans_private_files(self):
        inventory, material = self.capture()
        destination = self.destination()
        with mock.patch.object(CHECK.os, "fsync", side_effect=OSError("fixture disk failure")), self.assertRaises(OSError):
            self.install(inventory, material, destination)
        self.assertEqual((destination / "etc/machine-id").read_text(), "old fixture machine\n")
        self.assertTrue((destination / "etc/puppetlabs/puppet/ssl/old-only").is_file())
        self.assertEqual(list((destination / "etc/puppetlabs/puppet").glob(".nest-stage3-identity-*")), [])

    def test_destination_symlink_refuses_without_touching_referent(self):
        inventory, material = self.capture()
        destination = self.destination()
        target = destination / "etc/machine-id"
        target.unlink()
        target.symlink_to(self.identity / "etc/machine-id")
        before = target.read_bytes()
        with self.assertRaises(ValueError):
            self.install(inventory, material, destination)
        self.assertEqual(target.read_bytes(), before)

    def test_removal_failure_aborts_install_and_cleans_staging(self):
        inventory, material = self.capture()
        destination = self.destination()
        original = CHECK.shutil.rmtree
        def refuse(path, *args, **kwargs):
            if Path(path) == destination / "etc/puppetlabs/puppet/ssl":
                raise PermissionError("fixture old-tree removal failure")
            return original(path, *args, **kwargs)
        with mock.patch.object(CHECK.shutil, "rmtree", side_effect=refuse), self.assertRaises(PermissionError):
            self.install(inventory, material, destination)
        self.assertEqual((destination / "etc/machine-id").read_text(), "old fixture machine\n")
        self.assertTrue((destination / "etc/puppetlabs/puppet/ssl/old-only").exists())
        self.assertEqual(list((destination / "etc/puppetlabs/puppet").glob(".nest-stage3-identity-*")), [])

    def test_staging_outer_directory_remains_private_during_install(self):
        inventory, material = self.capture()
        destination = self.destination()
        original = CHECK.os.rename
        def rename(source, target):
            stage = next((destination / "etc/puppetlabs/puppet").glob(".nest-stage3-identity-*"))
            self.assertEqual(stage.stat().st_mode & 0o777, 0o700)
            return original(source, target)
        with mock.patch.object(CHECK.os, "rename", side_effect=rename):
            self.install(inventory, material, destination)

    def test_capture_has_total_size_and_entry_limits(self):
        for number in range(17):
            path = self.ssl / ("fixture-padding-" + str(number))
            path.write_bytes(b"x" * (1024 * 1024))
            path.chmod(0o600)
        with self.assertRaises(ValueError):
            self.capture()
        for path in self.ssl.glob("fixture-padding-*"):
            path.unlink()
        for number in range(4096):
            (self.ssl / ("empty-" + str(number))).mkdir()
        with self.assertRaises(ValueError):
            CHECK.identity_inventory(self.identity)

    def test_cli_install_refuses_nonroot_and_is_sanitized(self):
        # Never let the test runner's own container/root status authorize an
        # install into its /etc. Positive CLI execution uses a disposable container.
        stdout, stderr = io.StringIO(), io.StringIO()
        args = ["checker", str(self.identity), str(self.output), "fixture-host", self.pin, "--install"]
        with mock.patch.object(CHECK.os, "geteuid", return_value=1000), mock.patch.object(sys, "argv", args), \
                mock.patch.object(CHECK, "install_capture") as install, \
                contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            self.assertEqual(CHECK.main(), 1)
            install.assert_not_called()
        self.assertEqual(stdout.getvalue(), "")
        self.assertEqual(stderr.getvalue(), "Stage 3 identity/path admission failed\n")
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
