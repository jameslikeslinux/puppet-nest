"""Dependency-free checks for the trusted TEST artifact-import boundary."""

import contextlib
import importlib.util
import io
import json
import sys
import types
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

MODULE = Path(__file__).resolve().parents[3] / "files/app/joyride/import_artifacts.py"
spec = importlib.util.spec_from_file_location("import_artifacts", MODULE)
assert spec is not None and spec.loader is not None
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class ImportTests(unittest.TestCase):
    def evidence(self):
        pipeline = dict(id=12, project_id=83, status="success", sha="a" * 40,
                        web_url="https://gitlab.joyfullee.me/joy/joyride/-/pipelines/12")
        jobs = [dict(id=n, name=name, status="success") for n, name in enumerate(("check", "build", "smoke"), 1)]
        artifact = dict(head=pipeline["sha"], pipeline_id=12,
                        repository="registry.gitlab.joyfullee.me/joy/joyride/app",
                        digest="sha256:" + "b" * 64, platforms=["linux/amd64", "linux/arm64"])
        return pipeline, jobs, artifact

    def response(self, rows):
        return contextlib.closing(io.BytesIO(json.dumps(rows).encode()))

    def test_recent_successful_project_pipelines_oldest_first(self):
        rows = [dict(id=n, project_id=83, status="success") for n in (12, 11)]
        with patch.object(importer, "urlopen", return_value=self.response(rows)) as opened:
            self.assertEqual(importer.recent_pipelines("fixture-token"), [11, 12])
        request = opened.call_args.args[0]
        self.assertIn("status=success", request.full_url)
        self.assertEqual(request.headers["Private-token"], "fixture-token")

    def test_invalid_pipeline_identity_fails_closed(self):
        for row in (
            dict(id=True, project_id=83, status="success"),
            dict(id=1, project_id=82, status="success"),
            dict(id=1, project_id=83, status="running"),
        ):
            with self.subTest(row=row), patch.object(importer, "urlopen", return_value=self.response([row])):
                with self.assertRaises(ValueError):
                    importer.recent_pipelines("fixture-token")

    def test_existing_skipped_verified_read_back_and_failures_sanitized(self):
        seen = {1}
        attempted = []

        def verify(number):
            attempted.append(number)
            if number == 3:
                raise ValueError("fixture-sensitive-detail")
            seen.add(number)

        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = importer.import_pipelines([1, 2, 3, 4], seen.__contains__, verify)
        self.assertEqual(result, 1)
        self.assertEqual(attempted, [2, 3, 4])
        self.assertIn("imported 2, existing 1, failed 1", output.getvalue())
        self.assertNotIn("fixture-sensitive-detail", output.getvalue())

    def test_missing_readback_is_failure(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(importer.import_pipelines([1], lambda _: False, lambda _: None), 1)

    def test_legacy_architecture_is_not_eligible(self):
        pipeline, jobs, artifact = self.evidence()
        artifact["platforms"] = ["linux/amd64"]
        with patch.object(importer, "get", side_effect=[pipeline, jobs, artifact]):
            self.assertIsNone(importer.verified_evidence("fixture-token", 12))
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(importer.import_pipelines([1], lambda _: False, lambda _: False), 0)

    def test_invalid_or_incomplete_evidence_refused(self):
        for target, key, value in (
            (0, "project_id", 82), (0, "id", 13), (0, "status", "running"),
            (0, "sha", "invalid"), (0, "web_url", "https://untrusted.invalid"),
            (2, "head", "c" * 40), (2, "pipeline_id", 13),
            (2, "repository", "other/app"), (2, "digest", "latest"),
        ):
            evidence = list(self.evidence())
            item = evidence[target]
            assert isinstance(item, dict)
            item[key] = value
            with self.subTest(key=key), patch.object(importer, "get", side_effect=evidence):
                with self.assertRaises(ValueError):
                    importer.verified_evidence("fixture-token", 12)
        for jobs in ([], self.evidence()[1][:-1], self.evidence()[1] * 34):
            pipeline, _, artifact = self.evidence()
            with self.subTest(jobs=len(jobs)), patch.object(importer, "get", side_effect=[pipeline, jobs, artifact]):
                with self.assertRaises(ValueError):
                    importer.verified_evidence("fixture-token", 12)

    def test_equivalent_pipeline_preserves_original_receipt(self):
        self.run_importer("a" * 40, True, expected=0, calls=0)

    def test_conflicting_or_unverified_row_cannot_bypass_registration(self):
        self.run_importer("c" * 40, True, expected=1, calls=1)
        self.run_importer("a" * 40, False, expected=1, calls=1)

    def run_importer(self, source, passed, expected, calls):
        # Synthetic existing branch receipt; later MR pipeline has identical
        # bytes. The real application rejects rewriting its original URL.
        row = dict(digest="sha256:" + "b" * 64, source_head=source,
                   pipeline_url="https://gitlab.joyfullee.me/joy/joyride/-/pipelines/11", test_passed=passed)
        original = row.copy()
        model = Mock()
        model.objects.filter.side_effect = lambda **query: types.SimpleNamespace(
            exists=lambda: all(row.get(k) == v for k, v in query.items()))
        command = Mock(side_effect=ValueError("immutable fixture conflict"))
        modules = {
            "django": types.SimpleNamespace(setup=lambda: None),
            "django.core.management": types.SimpleNamespace(call_command=command),
            "core.models": types.SimpleNamespace(Artifact=model),
        }
        with patch.dict(sys.modules, modules), patch.dict(importer.os.environ, {
            "RUNTIME_ENV": "test", "GITLAB_READ_API_TOKEN": "fixture-token"
        }), patch.object(importer, "recent_pipelines", return_value=[12]), patch.object(
            importer, "get", side_effect=self.evidence()
        ), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(importer.main(), expected)
        self.assertEqual(command.call_count, calls)
        self.assertEqual(row, original)

    def test_production_refused_before_external_access(self):
        with patch.dict(importer.os.environ, {"RUNTIME_ENV": "production"}), patch.object(importer, "urlopen") as opened:
            with self.assertRaises(ValueError):
                importer.main()
            opened.assert_not_called()


if __name__ == "__main__":
    unittest.main()
