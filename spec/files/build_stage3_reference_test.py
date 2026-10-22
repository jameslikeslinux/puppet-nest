#!/usr/bin/env python3
"""Private identity references using disposable synthetic TLS material only."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sys
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location("trust_fixtures", Path(__file__).with_name("build_stage3_trust_test.py"))
assert SPEC is not None and SPEC.loader is not None
TRUST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TRUST)
CHECK = TRUST.CHECK
REFERENCE = "12345678-1234-4123-8123-123456789abc"


class Stage3ReferenceTest(TRUST.Stage3TrustTest):
    def setUp(self):
        super().setUp()
        self.generations = self.root / "generations"
        self.generations.mkdir(mode=0o700)
        self.generation = self.generations / REFERENCE

    def publish(self):
        with self.fixture_namespace(), mock.patch.object(CHECK.os, "geteuid", return_value=0):
            CHECK.publish_reference(str(self.identity), str(self.generation), "fixture-host", self.pin, REFERENCE)

    def consume(self, reference=REFERENCE):
        with self.fixture_namespace():
            return CHECK.capture(str(self.generation), str(self.output), "fixture-host", self.pin, reference)

    def marker(self):
        return self.generation / ".nest-identity.json"

    def test_publish_and_consume_survive_original_source_removal(self):
        before = {p.relative_to(self.identity): p.read_bytes() for p in self.identity.rglob("*") if p.is_file()}
        self.publish()
        self.assertEqual(self.generation.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.marker().stat().st_mode & 0o777, 0o400)
        shutil.rmtree(self.identity)
        inventory, material = self.consume()
        self.assertEqual(material, before)
        receipt = self.marker().read_bytes()
        self.consume()
        self.assertEqual(self.marker().read_bytes(), receipt)
        self.assertFalse(self.output.exists())
        self.assertEqual(json.loads(receipt)["reference"], REFERENCE)
        self.assertTrue(inventory)

    def test_existing_complete_or_partial_generation_never_overwritten(self):
        self.generation.mkdir(mode=0o700)
        with self.assertRaises(ValueError):
            self.publish()
        self.generation.rmdir()
        self.publish()
        before = self.marker().read_bytes()
        with self.assertRaises(ValueError):
            self.publish()
        self.assertEqual(self.marker().read_bytes(), before)

    def test_missing_truncated_extra_and_wrong_reference_marker_refuse(self):
        self.publish()
        path = self.marker()
        original = path.read_bytes()
        for raw in (b"", original[:20], original + b"extra", original.replace(REFERENCE.encode(), b"0" * len(REFERENCE))):
            path.chmod(0o600)
            path.write_bytes(raw)
            path.chmod(0o400)
            with self.subTest(raw_size=len(raw)), self.assertRaises(ValueError):
                self.consume()
        path.unlink()
        with self.assertRaises(OSError):
            self.consume()

    def test_changed_machine_or_ssl_material_or_membership_refuses(self):
        self.publish()
        machine = self.generation / "etc/machine-id"
        original = machine.read_bytes()
        machine.write_bytes(b"f" * 32 + b"\n")
        with self.assertRaises(ValueError):
            self.consume()
        machine.write_bytes(original)
        extra = self.generation / "etc/puppetlabs/puppet/ssl/extra"
        extra.mkdir()
        with self.assertRaises(ValueError):
            self.consume()
        extra.rmdir()
        key = self.generation / "etc/puppetlabs/puppet/ssl/private_keys/fixture-host.pem"
        key.chmod(0o400)
        with self.assertRaises(ValueError):
            self.consume()

    def test_wrong_uuid_directory_host_and_ca_binding_refuse(self):
        self.publish()
        for reference in ("latest", REFERENCE + "\n", "22345678-1234-4123-8123-123456789abc"):
            with self.subTest(reference=reference), self.assertRaises(ValueError):
                self.consume(reference)
        with self.fixture_namespace(), self.assertRaises((OSError, ValueError)):
            CHECK.capture(str(self.generation), str(self.output), "different-host", self.pin, REFERENCE)
        with self.fixture_namespace(), self.assertRaises(ValueError):
            CHECK.capture(str(self.generation), str(self.output), "fixture-host", "0" * 64, REFERENCE)

    def test_unsafe_parent_generation_or_marker_mode_refuses(self):
        self.generations.chmod(0o755)
        with self.assertRaises(ValueError):
            self.publish()
        self.generations.chmod(0o700)
        self.publish()
        self.generation.chmod(0o755)
        with self.assertRaises(ValueError):
            self.consume()
        self.generation.chmod(0o700)
        self.marker().chmod(0o644)
        with self.assertRaises(ValueError):
            self.consume()

    def test_source_capture_failure_never_creates_generation(self):
        with mock.patch.object(CHECK, "read_material", side_effect=OSError("private fixture failure")), self.assertRaises(OSError):
            self.publish()
        self.assertFalse(self.generation.exists())

    def test_install_failure_leaves_unaccepted_reservation_without_marker(self):
        with mock.patch.object(CHECK, "install_capture", side_effect=OSError("fixture disk failure")), self.assertRaises(OSError):
            self.publish()
        self.assertTrue(self.generation.is_dir())
        self.assertFalse(self.marker().exists())
        with self.assertRaises(ValueError):
            self.publish()
        with self.assertRaises(OSError):
            self.consume()

    def test_concurrent_reservation_cannot_replace_first_writer(self):
        original = CHECK.capture
        def competing(*args, **kwargs):
            value = original(*args, **kwargs)
            self.generation.mkdir(mode=0o700)
            return value
        with mock.patch.object(CHECK, "capture", side_effect=competing), self.assertRaises(FileExistsError):
            self.publish()
        self.assertEqual(list(self.generation.iterdir()), [])

    def test_reference_change_during_capture_refuses(self):
        self.publish()
        original = CHECK.read_material
        def changed(path):
            value = original(path)
            if path == self.generation / "etc/machine-id":
                self.marker().chmod(0o600)
                self.marker().write_bytes(b"changed private record\n")
                self.marker().chmod(0o400)
            return value
        with mock.patch.object(CHECK, "read_material", side_effect=changed), self.assertRaises(ValueError):
            self.consume()

    def test_cli_readonly_reference_success_and_failure_are_sanitized(self):
        self.publish()
        args = ["checker", str(self.generation), str(self.output), "fixture-host", self.pin, "--identity-reference", REFERENCE]
        for corrupt in (False, True):
            if corrupt:
                (self.generation / "etc/machine-id").write_bytes(b"f" * 32 + b"\n")
            stdout, stderr = io.StringIO(), io.StringIO()
            with self.fixture_namespace(), mock.patch.object(sys, "argv", args), \
                    contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                self.assertEqual(CHECK.main(), 1 if corrupt else 0)
            self.assertEqual(stdout.getvalue(), "" if corrupt else "Stage 3 identity/path admission passed\n")
            self.assertEqual(stderr.getvalue(), "Stage 3 identity/path admission failed\n" if corrupt else "")
        self.assertFalse(self.output.exists())

    def test_publish_cli_requires_root_without_printing_private_diagnostics(self):
        args = ["checker", str(self.identity), str(self.generation), "fixture-host", self.pin, "--publish-reference", REFERENCE]
        stdout, stderr = io.StringIO(), io.StringIO()
        with mock.patch.object(CHECK.os, "geteuid", return_value=1000), mock.patch.object(sys, "argv", args), \
                contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            self.assertEqual(CHECK.main(), 1)
        self.assertEqual(stdout.getvalue(), "")
        self.assertEqual(stderr.getvalue(), "Stage 3 identity/path admission failed\n")
        self.assertFalse(self.generation.exists())


if __name__ == "__main__":
    unittest.main()
