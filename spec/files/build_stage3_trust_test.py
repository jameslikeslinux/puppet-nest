#!/usr/bin/env python3
"""Real offline OpenSSL fixtures. No deployed keys, host builds or network access."""

import contextlib
import hashlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("stage3_trust", ROOT / "files/build/check-stage3-paths.py")
assert SPEC is not None and SPEC.loader is not None
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class Stage3TrustTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.fixtures = Path(cls.temporary.name).resolve()
        cls.command("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "2",
                    "-subj", "/CN=Fixture CA", "-keyout", "ca.key", "-out", "ca.pem",
                    "-addext", "basicConstraints=critical,CA:TRUE", "-addext", "keyUsage=critical,keyCertSign,cRLSign")
        cls.command("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "2",
                    "-subj", "/CN=Other Fixture CA", "-keyout", "other.key", "-out", "other.pem")
        (cls.fixtures / "ca-index").write_text("")
        (cls.fixtures / "ca-index.attr").write_text("unique_subject = no\n")
        (cls.fixtures / "ca-serial").write_text("01\n")
        (cls.fixtures / "ca.cnf").write_text(
            "[ca]\ndefault_ca=fixture\n[fixture]\ndatabase=ca-index\nserial=ca-serial\n"
            "new_certs_dir=.\ncertificate=ca.pem\nprivate_key=ca.key\ndefault_md=sha256\n"
            "policy=fixture_policy\n[fixture_policy]\ncommonName=supplied\n")
        for name, subject, purpose, days, ca in [
                ("valid", "fixture-host", "clientAuth,serverAuth", "1", "ca"),
                ("wrong-host", "another-host", "clientAuth", "1", "ca"),
                ("expired", "fixture-host", "clientAuth", "-1", "ca"),
                ("future", "fixture-host", "clientAuth", "-1", "ca"),
                ("wrong-purpose", "fixture-host", "serverAuth", "1", "ca"),
                ("untrusted", "fixture-host", "clientAuth", "1", "other"),
                ("wildcard", "*", "clientAuth", "1", "ca")]:
            cls.command("req", "-new", "-newkey", "rsa:2048", "-nodes", "-subj", "/CN=" + subject,
                        "-keyout", name + ".key", "-out", name + ".csr")
            (cls.fixtures / (name + ".ext")).write_text(
                "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\n"
                "extendedKeyUsage=" + purpose + "\nsubjectAltName=DNS:fixture-host\n")
            if name in ("expired", "future"):
                start, end = (("20000101000000Z", "20010101000000Z") if name == "expired"
                              else ("20990101000000Z", "21000101000000Z"))
                cls.command("ca", "-batch", "-notext", "-config", "ca.cnf", "-in", name + ".csr",
                            "-startdate", start, "-enddate", end, "-extfile", name + ".ext", "-out", name + ".pem")
            else:
                cls.command("x509", "-req", "-in", name + ".csr", "-CA", ca + ".pem", "-CAkey", ca + ".key",
                            "-set_serial", "1234", "-days", days, "-extfile", name + ".ext", "-out", name + ".pem")
        cls.command("pkey", "-in", "valid.key", "-aes-256-cbc", "-passout", "pass:fixture-only", "-out", "encrypted.key")
        cls.pin = hashlib.sha256((cls.fixtures / "ca.pem").read_bytes()).hexdigest()

    @classmethod
    def command(cls, *arguments):
        result = subprocess.run(["/usr/bin/openssl", *arguments], cwd=cls.fixtures,
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                                env={"PATH": "/usr/bin:/bin", "OPENSSL_CONF": "/dev/null"}, timeout=15)
        if result.returncode != 0:
            raise AssertionError("OpenSSL fixture generation failed: " + repr(arguments) + ": " + result.stderr.decode())

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.identity = self.root / "identity"
        self.output = self.root / "release"
        self.ssl = self.identity / "etc/puppetlabs/puppet/ssl"
        (self.ssl / "certs").mkdir(parents=True, mode=0o700)
        (self.ssl / "private_keys").mkdir(mode=0o700)
        (self.identity / "etc/machine-id").write_text("1234567890abcdef1234567890abcdef\n")
        self.ca = self.ssl / "certs/ca.pem"
        shutil.copyfile(self.fixtures / "ca.pem", self.ca)
        self.certificate = self.ssl / "certs/fixture-host.pem"
        self.key = self.ssl / "private_keys/fixture-host.pem"
        self.select("valid")

    def select(self, name):
        shutil.copyfile(self.fixtures / (name + ".pem"), self.certificate)
        shutil.copyfile(self.fixtures / (name + ".key"), self.key)
        self.key.chmod(0o600)

    @contextlib.contextmanager
    def fixture_namespace(self):
        # Model only ownership and the protected outer namespace. All material,
        # permissions, reads, parsing, subprocess and cryptographic checks are real.
        directory, file_check = CHECK.safe_directory, CHECK.safe_file
        uid, gid = os.getuid(), os.getgid()
        def check_directory(path, owners, groups):
            if path not in self.root.parents:
                directory(path, owners | {uid}, groups | {gid})
        with mock.patch.object(CHECK, "trusted_owners", return_value=({uid}, {gid})), \
                mock.patch.object(CHECK, "safe_directory", side_effect=check_directory), \
                mock.patch.object(CHECK, "safe_file", side_effect=lambda p, u, private=False: file_check(p, u | {uid}, private)):
            yield

    def check(self, pin=None):
        with self.fixture_namespace():
            CHECK.check(str(self.identity), str(self.output), "fixture-host", self.pin if pin is None else pin)

    def test_valid_exact_pinned_identity_is_read_only(self):
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns, p.stat().st_mode)
                  for p in self.identity.rglob("*") if p.is_file()}
        self.check()
        self.check()
        self.assertEqual(before, {p: (p.read_bytes(), p.stat().st_mtime_ns, p.stat().st_mode) for p in before})
        self.assertFalse(self.output.exists())

    def test_unapproved_ca_pin_refuses_even_with_valid_chain(self):
        for pin in ("0" * 64, "main", self.pin + "\n"):
            with self.subTest(pin=pin), self.assertRaises(ValueError):
                self.check(pin)

    def test_wrong_host_expiry_purpose_issuer_and_wildcard_refuse(self):
        for name in ("wrong-host", "expired", "future", "wrong-purpose", "untrusted", "wildcard"):
            self.select(name)
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.check()

    def test_mismatched_private_key_refuses(self):
        shutil.copyfile(self.fixtures / "wrong-host.key", self.key)
        with self.assertRaises(ValueError):
            self.check()

    def test_encrypted_or_malformed_private_key_refuses_without_prompt(self):
        for payload in ((self.fixtures / "encrypted.key").read_bytes(), b"malformed fixture private key"):
            self.key.write_bytes(payload)
            with self.assertRaises(ValueError):
                self.check()

    def test_extra_pem_material_refuses(self):
        for target in (self.key, self.certificate):
            original = target.read_bytes()
            target.write_bytes(original + original)
            with self.assertRaises(ValueError):
                self.check()
            target.write_bytes(original)

    def test_missing_tool_timeout_and_failed_tool_are_sanitized(self):
        for failure in (FileNotFoundError(), subprocess.TimeoutExpired("fixture", 15), ValueError("private fixture diagnostic")):
            stdout, stderr = io.StringIO(), io.StringIO()
            args = ["checker", str(self.identity), str(self.output), "fixture-host", self.pin]
            with self.fixture_namespace(), mock.patch.object(sys, "argv", args), \
                    mock.patch.object(CHECK, "openssl", side_effect=failure), \
                    contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                self.assertEqual(CHECK.main(), 1)
            self.assertEqual(stdout.getvalue(), "")
            self.assertEqual(stderr.getvalue(), "Stage 3 identity/path admission failed\n")

    def test_real_subprocess_exit_is_checked_and_environment_is_restricted(self):
        with mock.patch.object(CHECK.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, b"private")) as run:
            with self.assertRaises(ValueError):
                CHECK.openssl(["x509"], b"fixture")
            self.assertEqual(run.call_args.kwargs["env"], {"PATH": "/usr/bin:/bin", "OPENSSL_CONF": "/dev/null"})
            self.assertEqual(run.call_args.kwargs["timeout"], 15)
            self.assertNotIn("shell", run.call_args.kwargs)

    def test_exact_ca_bytes_are_sealed_and_not_default_trust(self):
        original = CHECK.openssl
        def verify(arguments, payload, descriptors=()):
            if arguments[0] == "verify":
                import fcntl
                descriptor, = descriptors
                with self.assertRaises(PermissionError):
                    os.write(descriptor, b"mutation")
                self.assertTrue(fcntl.fcntl(descriptor, fcntl.F_GET_SEALS) & fcntl.F_SEAL_WRITE)
                self.assertIn("-no-CAstore", arguments)
                self.assertIn("-no-CAfile", arguments)
                self.assertIn("-no-CApath", arguments)
            return original(arguments, payload, descriptors)
        with mock.patch.object(CHECK, "openssl", side_effect=verify):
            self.check()


if __name__ == "__main__":
    unittest.main()
