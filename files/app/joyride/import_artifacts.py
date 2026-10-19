"""Import recent independently verified CI artifacts; never deploy or publish them.

Runs only in the isolated TEST importer with project-scoped read_api access.
The application management command owns exact-head/job/image verification.
"""

import io
import json
import os
import sys
from urllib.request import Request, urlopen

API = "https://gitlab.joyfullee.me/api/v4/projects/83"


def get(token, path):
    request = Request(API + path, headers={"PRIVATE-TOKEN": token})
    with urlopen(request, timeout=20) as response:
        return json.load(response)


def recent_pipelines(token):
    rows = get(token, "/pipelines?status=success&order_by=id&sort=desc&per_page=5")
    if not isinstance(rows, list) or len(rows) > 5:
        raise ValueError("invalid pipeline list")
    for row in reversed(rows):
        if (
            type(row.get("id")) is not int
            or row["id"] < 1
            or row.get("status") != "success"
            or row.get("project_id") != 83
        ):
            raise ValueError("invalid pipeline identity")
    return [row["id"] for row in reversed(rows)]


def supported_pipeline(token, pipeline_id):
    jobs = get(token, f"/pipelines/{pipeline_id}/jobs?per_page=100")
    build = next(j for j in jobs if j["name"] == "build" and j["status"] == "success")
    artifact = get(token, f"/jobs/{build['id']}/artifacts/image.json")
    # Ordinary Eyrie workers include both architectures. Legacy amd64-only
    # artifacts are not eligible, even if their original CI succeeded.
    return set(artifact.get("platforms", [])) == {"linux/amd64", "linux/arm64"}


def import_pipelines(pipeline_ids, registered, verify):
    imported = skipped = failed = 0
    for pipeline_id in pipeline_ids:
        if registered(pipeline_id):
            skipped += 1
            continue
        try:
            if verify(pipeline_id) is False:
                skipped += 1
                continue
            # Verification success must be followed by database readback.
            if not registered(pipeline_id):
                raise ValueError("artifact readback failed")
            imported += 1
        except Exception:
            # Never print urllib errors, tokens, command output or tracebacks.
            failed += 1
    print(f"Artifact import: imported {imported}, existing {skipped}, failed {failed}")
    return 1 if failed else 0


def main():
    if os.environ.get("RUNTIME_ENV") != "test":
        raise ValueError("TEST importer only")
    token = os.environ["GITLAB_READ_API_TOKEN"]
    if not token:
        raise ValueError("verifier credential required")
    pipeline_ids = recent_pipelines(token)
    sys.path.insert(0, "/app")
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "joyride.settings")
    import django

    django.setup()
    from django.core.management import call_command
    from core.models import Artifact

    def registered(pipeline_id):
        return Artifact.objects.filter(
            pipeline_url=f"https://gitlab.joyfullee.me/joy/joyride/-/pipelines/{pipeline_id}",
            test_passed=True,
        ).exists()

    def verify(pipeline_id):
        if not supported_pipeline(token, pipeline_id):
            return False
        call_command("register_artifact", pipeline_id, stdout=io.StringIO(), stderr=io.StringIO())

    return import_pipelines(pipeline_ids, registered, verify)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        print("Artifact import failed; inspect sanitized job status", file=sys.stderr)
        sys.exit(1)
