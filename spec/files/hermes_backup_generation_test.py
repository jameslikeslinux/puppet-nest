from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import fcntl
import json
import hashlib
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import textwrap
from typing import cast
import unittest
from unittest import mock
import zipfile


sys.dont_write_bytecode = True

REPO_ROOT = Path(__file__).resolve().parents[2]
HELPER = REPO_ROOT / "files" / "hermes-backup-generation"
PROFILES = ("talon", "star", "beryl", "quill")
loader = importlib.machinery.SourceFileLoader('hermes_generation', str(HELPER))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
generation = importlib.util.module_from_spec(spec)
loader.exec_module(generation)


class HermesBackupGenerationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.backup_dir = self.root / "backups"
        self.call_log = self.root / "calls"
        self.fake_hermes = self.root / "hermes"
        self.fake_hermes.write_text(
            textwrap.dedent(
                f"""\
                #!{sys.executable}
                import os
                from pathlib import Path
                import sys
                import zipfile

                args = sys.argv[1:]
                if args[0] != "backup" or args[1] != "--output":
                    raise SystemExit(2)
                output = Path(args[2])
                if not output.is_relative_to(Path(os.environ['TMPDIR'])):
                    raise SystemExit('capture output must be inside local native scratch')
                print('native progress belongs on stderr, not the JSON receipt')
                with Path(os.environ["HERMES_TEST_CALL_LOG"]).open("a") as log:
                    log.write("backup\\n")
                with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
                    archive.writestr("config.yaml", "model: test\\n")
                    archive.writestr("auth.json", '{{"providers": {{}}}}\\n')
                    archive.writestr("kanban.db", "shared-kanban")
                    for profile in {PROFILES!r}:
                        archive.writestr(f"profiles/{{profile}}/config.yaml", f"profile: {{profile}}\\n")
                """
            ),
            encoding="utf-8",
        )
        self.fake_hermes.chmod(0o700)
        self.environment = os.environ.copy()
        self.environment["HERMES_TEST_CALL_LOG"] = str(self.call_log)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_helper(self, *args: str) -> dict[str, object]:
        result = subprocess.run(
            [sys.executable, str(HELPER), *args],
            check=True,
            capture_output=True,
            env=self.environment,
            text=True,
        )
        return json.loads(result.stdout)

    def backup(self, checkpoint: str, retain: int = 24, *extra: str) -> dict[str, object]:
        return self.run_helper(
            "backup",
            "--backup-dir",
            str(self.backup_dir),
            "--hermes-bin",
            str(self.fake_hermes),
            "--stage-dir",
            str(self.root / 'stage'),
            "--checkpoint",
            checkpoint,
            "--retain",
            str(retain),
            *extra,
        )

    def test_capture_is_local_and_final_receipt_matches_bytes(self) -> None:
        result = self.backup('local-capture')
        archive = self.backup_dir / str(result['archive'])
        self.assertEqual(result['sha256'], hashlib.sha256(archive.read_bytes()).hexdigest())
        receipt = json.loads(archive.with_suffix('.json').read_text())
        self.assertEqual(receipt['sha256'], result['sha256'])
        self.assertEqual(stat.S_IMODE(archive.with_suffix('.json').stat().st_mode), 0o600)
        self.assertEqual(list((self.root / 'stage').iterdir()), [])
        self.assertEqual(list(self.backup_dir.glob('*.transfer')), [])

    def verify_args(self, receipt: dict[str, object]):
        args = generation.parser().parse_args([
            'verify', '--backup-dir', str(self.backup_dir), '--checkpoint', str(receipt['checkpoint']),
            '--expected-sha256', str(receipt['sha256']), '--max-age-seconds', '3600',
        ])
        args.required_profile = list(PROFILES)
        return args

    def test_verify_reads_exact_generation_without_capture_prune_or_content_output(self) -> None:
        self.backup('previous')
        receipt = self.backup('current')
        before = {path.name: (path.read_bytes(), path.stat().st_mtime_ns, path.stat().st_mode) for path in self.backup_dir.iterdir()}
        result = self.run_helper('verify', '--backup-dir', str(self.backup_dir), '--checkpoint', 'current',
                                 '--expected-sha256', str(receipt['sha256']), '--max-age-seconds', '3600')
        self.assertEqual(result['action'], 'verified')
        self.assertEqual(result['sha256'], receipt['sha256'])
        self.assertFalse(result['restore_verified'])
        self.assertFalse(result['execution_authorized'])
        self.assertNotIn('providers', json.dumps(result))
        self.assertEqual(self.call_log.read_text(), 'backup\nbackup\n')
        after = {path.name: (path.read_bytes(), path.stat().st_mtime_ns, path.stat().st_mode) for path in self.backup_dir.iterdir()}
        self.assertEqual(after, before)

    def test_verify_missing_storage_or_lock_does_not_initialize_it(self) -> None:
        args = self.verify_args({'checkpoint': 'missing', 'sha256': 'a' * 64})
        with self.assertRaises(FileNotFoundError):
            generation.verify_generation(args)
        self.assertFalse(self.backup_dir.exists())
        self.backup_dir.mkdir(mode=0o700)
        with self.assertRaises(FileNotFoundError):
            generation.verify_generation(args)
        self.assertEqual(list(self.backup_dir.iterdir()), [])

    def test_verify_refuses_busy_retention_lock_without_waiting(self) -> None:
        args = self.verify_args(self.backup('locked'))
        with (self.backup_dir / '.generation.lock').open('rb') as lock:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
            with self.assertRaises(BlockingIOError):
                generation.verify_generation(args)

    def test_verify_refuses_same_size_corruption_and_wrong_expected_digest(self) -> None:
        receipt = self.backup('corrupt-verification')
        args = self.verify_args(receipt)
        args.expected_sha256 = 'a' * 64
        with self.assertRaises(RuntimeError):
            generation.verify_generation(args)
        args.expected_sha256 = receipt['sha256']
        archive = self.backup_dir / str(receipt['archive'])
        raw = bytearray(archive.read_bytes())
        raw[50] ^= 1
        archive.write_bytes(raw)
        with self.assertRaises(RuntimeError):
            generation.verify_generation(args)

    def test_verify_refuses_malformed_incomplete_or_miscounted_receipts(self) -> None:
        receipt = self.backup('bad-receipt')
        args = self.verify_args(receipt)
        path = self.backup_dir / 'hermes-home-bad-receipt.json'
        original = json.loads(path.read_text())
        mutations = [[], None, {'verified': False}, {'format': 'profile-backup'}, {'members': 999},
                     {'bytes': True}, {'required_shared': []}, {'required_profiles': None},
                     {'required_profiles': [{}]}, {'required_profiles': ['talon']},
                     {'created_at': '2030-02-30T00:00:00Z'}, {'created_at': '2030-01-01T00:00:00+00:00'}]
        for mutation in mutations:
            changed = dict(original, **mutation) if isinstance(mutation, dict) else mutation
            path.write_text(json.dumps(changed))
            with self.subTest(mutation=mutation), self.assertRaises((RuntimeError, ValueError)):
                generation.verify_generation(args)

    def test_verify_checks_age_after_hash_and_refuses_future_timestamp(self) -> None:
        receipt = self.backup('age')
        args = self.verify_args(receipt)
        path = self.backup_dir / 'hermes-home-age.json'
        metadata = json.loads(path.read_text())
        metadata['created_at'] = '2030-01-01T00:00:00Z'
        path.write_text(json.dumps(metadata))
        for hour, allowed in [(0, True), (1, True), (2, False)]:
            with self.subTest(hour=hour), mock.patch.object(generation, 'datetime', wraps=datetime) as clock:
                clock.now.return_value = datetime(2030, 1, 1, hour, tzinfo=timezone.utc)
                if allowed:
                    self.assertEqual(generation.verify_generation(args)['action'], 'verified')
                else:
                    with self.assertRaises(RuntimeError):
                        generation.verify_generation(args)
        with mock.patch.object(generation, 'datetime', wraps=datetime) as clock:
            clock.now.return_value = datetime(2029, 12, 31, 23, 59, 59, tzinfo=timezone.utc)
            with self.assertRaises(RuntimeError):
                generation.verify_generation(args)

    def test_verify_refuses_public_files_and_symlinks_without_permission_repair(self) -> None:
        receipt = self.backup('private')
        args = self.verify_args(receipt)
        self.backup_dir.chmod(0o755)
        with self.assertRaises(RuntimeError):
            generation.verify_generation(args)
        self.assertEqual(stat.S_IMODE(self.backup_dir.stat().st_mode), 0o755)
        self.backup_dir.chmod(0o700)
        archive = self.backup_dir / str(receipt['archive'])
        archive.chmod(0o644)
        with self.assertRaises(RuntimeError):
            generation.verify_generation(args)
        self.assertEqual(stat.S_IMODE(archive.stat().st_mode), 0o644)
        archive.chmod(0o600)
        saved = archive.with_suffix('.saved')
        archive.rename(saved)
        archive.symlink_to(saved)
        with self.assertRaises(RuntimeError):
            generation.verify_generation(args)

    def test_verify_requires_explicit_bounded_age_and_literal_digest(self) -> None:
        args = self.verify_args(self.backup('policy'))
        for age in (0, -1, 604801):
            args.max_age_seconds = age
            with self.assertRaises(ValueError):
                generation.verify_generation(args)
        args.max_age_seconds = 3600
        for digest in ('latest', 'sha256:' + 'a' * 64, 'A' * 64):
            args.expected_sha256 = digest
            with self.assertRaises(ValueError):
                generation.verify_generation(args)

    def test_failed_capture_keeps_previous_generation_and_publishes_nothing(self) -> None:
        first = self.backup('prior')
        self.fake_hermes.write_text(f'#!{sys.executable}\nimport sys\nsys.exit(9)\n')
        with self.assertRaises(subprocess.CalledProcessError):
            self.backup('failed')
        self.assertTrue((self.backup_dir / str(first['archive'])).exists())
        self.assertFalse((self.backup_dir / 'hermes-home-failed.zip').exists())
        self.assertFalse((self.backup_dir / 'hermes-home-failed.json').exists())
        self.assertEqual(list((self.root / 'stage').iterdir()), [])

    def test_final_storage_cannot_be_capture_scratch(self) -> None:
        with self.assertRaises(ValueError):
            generation._local_stage(self.backup_dir / 'stage', self.backup_dir)
        with mock.patch.object(generation.subprocess, 'run', return_value=mock.Mock(stdout='nfs4\n')):
            with self.assertRaises(ValueError):
                generation._local_stage(self.root / 'network-stage', self.backup_dir)

    def test_transfer_failure_and_collision_never_overwrite_final(self) -> None:
        staged = self.root / 'staged.zip'
        staged.write_bytes(b'new verified archive')
        self.backup_dir.mkdir()
        final = self.backup_dir / 'hermes-home-collision.zip'
        final.write_bytes(b'prior archive')
        digest = generation._sha256(staged)
        with self.assertRaises(FileExistsError):
            generation._publish_archive(staged, final, digest)
        self.assertEqual(final.read_bytes(), b'prior archive')
        final.unlink()
        with mock.patch.object(generation.shutil, 'copyfileobj', side_effect=OSError('injected ENOSPC')):
            with self.assertRaises(OSError):
                generation._publish_archive(staged, final, digest)
        self.assertFalse(final.exists())
        self.assertEqual(list(self.backup_dir.iterdir()), [])

    def test_metadata_failure_is_not_reused_or_pruned(self) -> None:
        self.backup('prior')
        args = generation.parser().parse_args([
            'backup', '--backup-dir', str(self.backup_dir), '--stage-dir', str(self.root / 'stage'),
            '--hermes-bin', str(self.fake_hermes), '--checkpoint', 'no-receipt', '--retain', '1',
        ])
        args.required_profile = list(PROFILES)
        with mock.patch.dict(os.environ, self.environment), mock.patch.object(
            generation, '_atomic_json', side_effect=OSError('injected receipt failure'),
        ):
            with self.assertRaises(OSError):
                generation.create_generation(args)
        self.assertTrue((self.backup_dir / 'hermes-home-prior.zip').exists())
        with self.assertRaises(subprocess.CalledProcessError):
            self.backup('no-receipt')
        self.assertEqual(self.call_log.read_text(), 'backup\nbackup\n')

    def test_no_prune_preserves_all_prior_generations(self) -> None:
        self.backup('prior')
        result = self.backup('preserved', 1, '--no-prune')
        self.assertEqual(result['pruned'], [])
        self.assertEqual(len(list(self.backup_dir.glob('*.zip'))), 2)

    def test_incomplete_archive_is_never_published(self) -> None:
        self.fake_hermes.write_text(textwrap.dedent(f'''\
            #!{sys.executable}
            import sys, zipfile
            with zipfile.ZipFile(sys.argv[3], 'w') as archive:
                archive.writestr('config.yaml', 'incomplete')
        '''))
        with self.assertRaises(subprocess.CalledProcessError):
            self.backup('incomplete')
        self.assertFalse(list(self.backup_dir.glob('*.zip')))
        self.assertFalse(list(self.backup_dir.glob('*.json')))

    def test_same_size_corruption_is_not_reused(self) -> None:
        result = self.backup('corrupt')
        archive = self.backup_dir / str(result['archive'])
        payload = bytearray(archive.read_bytes())
        # Change payload bytes but leave the central directory and length intact.
        payload[50] ^= 1
        archive.write_bytes(payload)
        with self.assertRaises(subprocess.CalledProcessError):
            self.backup('corrupt')
        self.assertEqual(self.call_log.read_text(), 'backup\n')

    def test_four_profile_callers_create_one_restorable_full_home_generation(self) -> None:
        # Exercise real independent publishers contending on the generation flock.
        with ThreadPoolExecutor(max_workers=len(PROFILES)) as executor:
            results = list(executor.map(lambda _profile: self.backup("rollout-326eb96b"), PROFILES))

        self.assertEqual([result["action"] for result in results].count("created"), 1)
        self.assertEqual([result["action"] for result in results].count("reused"), 3)
        self.assertEqual(self.call_log.read_text(encoding="utf-8"), "backup\n")
        archives = list(self.backup_dir.glob("*.zip"))
        self.assertEqual([archive.name for archive in archives], ["hermes-home-rollout-326eb96b.zip"])
        self.assertFalse(any(profile in archives[0].name for profile in PROFILES))
        self.assertEqual(stat.S_IMODE(archives[0].stat().st_mode), 0o600)

        restore_root = self.root / "restored"
        with zipfile.ZipFile(archives[0]) as archive:
            self.assertIsNone(archive.testzip())
            archive.extractall(restore_root)
        self.assertEqual((restore_root / "kanban.db").read_text(), "shared-kanban")
        for profile in PROFILES:
            self.assertEqual(
                (restore_root / "profiles" / profile / "config.yaml").read_text(),
                f"profile: {profile}\n",
            )

    def test_retention_is_global_generation_count(self) -> None:
        self.backup("checkpoint-1", retain=2)
        self.backup("checkpoint-2", retain=2)
        self.backup("checkpoint-3", retain=2)

        self.assertEqual(
            sorted(path.name for path in self.backup_dir.glob("*.zip")),
            ["hermes-home-checkpoint-2.zip", "hermes-home-checkpoint-3.zip"],
        )

    def test_legacy_cleanup_dry_run_is_exact_and_apply_preserves_newest(self) -> None:
        self.backup("known-good")
        legacy = []
        for index, profile in enumerate(PROFILES):
            path = self.backup_dir / f"{profile}-hermes-2026092{index}-010203.zip"
            path.write_bytes(bytes([index]))
            os.utime(path, (index + 1, index + 1))
            legacy.append(path)

        dry_run = self.run_helper("legacy-cleanup", "--backup-dir", str(self.backup_dir))
        self.assertEqual(dry_run["action"], "legacy-cleanup-dry-run")
        self.assertEqual(dry_run["protected_newest_legacy"], [str(legacy[-1])])
        candidates = cast(list[str], dry_run["candidates"])
        self.assertIsInstance(candidates, list)
        self.assertEqual(set(candidates), {str(path) for path in legacy[:-1]})
        self.assertTrue(all(path.exists() for path in legacy))

        applied = self.run_helper(
            "legacy-cleanup",
            "--backup-dir",
            str(self.backup_dir),
            "--apply",
        )
        self.assertEqual(applied["readback_survivors"], [str(legacy[-1])])
        self.assertTrue(legacy[-1].exists())
        self.assertTrue(all(not path.exists() for path in legacy[:-1]))


if __name__ == "__main__":
    unittest.main()
