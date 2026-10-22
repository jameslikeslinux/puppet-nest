#!/usr/bin/env python3
"""Real Git, local-only frozen input fixtures; no Podman, OS build or network."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "files/build/freeze-repos.py"
URLS = [
    "https://gitlab.joyfullee.me/nest/gentoo/portage.git",
    "https://gitlab.joyfullee.me/nest/overlay.git",
    "https://gitlab.joyfullee.me/nest/gentoo/haskell.git",
]


class FrozenRepositoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nest-frozen-inputs-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.source = self.base / "source"
        self.root = self.base / "repos"
        self.source.mkdir()
        self.root.mkdir()
        self.env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_ALLOW_PROTOCOL="file", GIT_AUTHOR_NAME="Fixture", GIT_COMMITTER_NAME="Fixture",
                        GIT_AUTHOR_EMAIL="fixture@example.invalid", GIT_COMMITTER_EMAIL="fixture@example.invalid")
        self.git(self.source, "init", "--quiet")
        (self.source / "tracked").write_text("frozen\n")
        (self.source / ".gitignore").write_text("ignored\n")
        self.git(self.source, "add", ".")
        self.git(self.source, "commit", "--quiet", "-m", "Fixture first input")
        self.sha = self.git(self.source, "rev-parse", "HEAD").stdout.strip()
        (self.source / "tracked").write_text("later mutable input\n")
        self.git(self.source, "commit", "--quiet", "-am", "Fixture moved main")
        self.later = self.git(self.source, "rev-parse", "HEAD").stdout.strip()
        # Redirect each fixed public origin to the fixture. All other transports are disabled.
        self.env["GIT_CONFIG_COUNT"] = "3"
        for i, url in enumerate(URLS):
            self.env["GIT_CONFIG_KEY_" + str(i)] = "url." + self.source.as_uri() + ".insteadOf"
            # Multiple values of this same key are supported by Git's config environment.
            self.env["GIT_CONFIG_VALUE_" + str(i)] = url

    def git(self, path, *args):
        return subprocess.run(["git", "-C", str(path), *args], env=self.env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)

    def run_helper(self, mode="prepare", pins=None, root=None):
        return subprocess.run([sys.executable, str(SCRIPT), mode, *(pins or [self.sha] * 3),
                               "--repos-dir", str(root or self.root)], env=self.env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)

    def prepare(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_prepares_exact_non_tip_commits_and_read_only_check(self):
        report = self.prepare()
        self.assertEqual(report["revisions"], dict.fromkeys(["gentoo", "nest", "haskell"], self.sha))
        for name in report["revisions"]:
            path = self.root / name
            self.assertEqual((path / "tracked").read_text(), "frozen\n")
            self.assertEqual(self.git(path, "rev-parse", "HEAD").stdout.strip(), self.sha)
        before = {str(p): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        result = self.run_helper("check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), report)
        self.assertEqual(before, {str(p): p.read_bytes() for p in self.root.rglob("*") if p.is_file()})
        self.assertEqual(self.git(self.root / "nest", "rev-parse", "HEAD").stdout.strip(), self.sha)

    def test_rejects_bad_pin_before_mutation(self):
        for bad in ["main", self.sha[:12], self.sha.upper(), self.sha + ";touch /unsafe", self.sha + "\n"]:
            result = self.run_helper(pins=[self.sha, bad, self.sha])
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(self.root.iterdir()), [])

    def test_refuses_existing_or_partial_directory_without_cleanup(self):
        marker = self.root / "keep"
        marker.write_text("previous evidence")
        self.assertNotEqual(self.run_helper().returncode, 0)
        self.assertEqual(marker.read_text(), "previous evidence")

    def test_failed_fetch_is_not_success_or_implicitly_retried(self):
        result = self.run_helper(pins=["f" * 40] * 3)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(result.stdout)
        self.assertEqual([p.name for p in self.root.iterdir()], ["gentoo"])
        self.assertNotEqual(self.run_helper().returncode, 0)

    def test_refuses_unknown_repository(self):
        self.prepare()
        (self.root / "extra").mkdir()
        self.assertNotEqual(self.run_helper("check").returncode, 0)

    def test_detects_head_origin_branch_and_content_drift(self):
        self.prepare()
        repo = self.root / "nest"
        self.git(repo, "fetch", "--quiet", "origin", self.later)
        self.git(repo, "checkout", "--quiet", "--detach", self.later)
        self.assertNotEqual(self.run_helper("check").returncode, 0)
        self.git(repo, "checkout", "--quiet", "--detach", self.sha)
        self.git(repo, "remote", "set-url", "origin", "https://example.invalid/wrong")
        self.assertNotEqual(self.run_helper("check").returncode, 0)
        self.git(repo, "remote", "set-url", "origin", URLS[1])
        self.git(repo, "checkout", "--quiet", "-b", "mutable")
        self.assertNotEqual(self.run_helper("check").returncode, 0)
        self.git(repo, "checkout", "--quiet", "--detach", self.sha)
        for name in ["tracked", "untracked", "ignored"]:
            path = repo / name
            original = path.read_bytes() if path.exists() else None
            path.write_text("unexpected input")
            self.assertNotEqual(self.run_helper("check").returncode, 0, name)
            if original is None:
                path.unlink()
            else:
                path.write_bytes(original)
        self.assertEqual(self.run_helper("check").returncode, 0)

    def test_refuses_symlink_root_or_member(self):
        alias = self.base / "alias"
        alias.symlink_to(self.root, target_is_directory=True)
        self.assertNotEqual(self.run_helper(root=alias).returncode, 0)
        self.prepare()
        (self.root / "nest").rename(self.base / "moved")
        (self.root / "nest").symlink_to(self.base / "moved", target_is_directory=True)
        self.assertNotEqual(self.run_helper("check").returncode, 0)

    def test_refuses_gitlink_as_an_unmaterialized_input(self):
        self.prepare()
        repo = self.root / "nest"
        self.git(repo, "update-index", "--add", "--cacheinfo", "160000," + self.sha + ",submodule")
        self.git(repo, "commit", "--quiet", "-m", "Fixture submodule")
        sha = self.git(repo, "rev-parse", "HEAD").stdout.strip()
        result = self.run_helper("check", pins=[self.sha, sha, self.sha])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("submodule", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
