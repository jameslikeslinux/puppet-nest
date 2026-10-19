"""Dependency-free checks for the trusted TEST artifact-import boundary."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[3] / "files/app/joyride/import_artifacts.py"
spec = importlib.util.spec_from_file_location("import_artifacts", MODULE)
assert spec is not None and spec.loader is not None
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class ImportTests(unittest.TestCase):
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
        jobs = [{"id": 2, "name": "build", "status": "success"}]
        for platforms, expected in [(["linux/amd64"], False), (["linux/amd64", "linux/arm64"], True)]:
            with patch.object(importer, "get", side_effect=[jobs, {"platforms": platforms}]):
                self.assertEqual(importer.supported_pipeline("fixture-token", 1), expected)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(importer.import_pipelines([1], lambda _: False, lambda _: False), 0)

    def test_production_refused_before_external_access(self):
        with patch.dict(importer.os.environ, {"RUNTIME_ENV": "production"}), patch.object(importer, "urlopen") as opened:
            with self.assertRaises(ValueError):
                importer.main()
            opened.assert_not_called()


if __name__ == "__main__":
    unittest.main()
