"""Install one immutable OSM basemap into managed TEST storage; never private routes."""

import hashlib
import json
import os
from pathlib import Path
import sys
from urllib.request import Request, urlopen

sys.path.insert(0, "/app")
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "joyride.settings")
import django

django.setup()
from django.core.management import call_command
from core.models import MapRelease

VERSION = "dc-md-va-20261018"
CHECKSUM = "41a28e1be0d79f22f609d8c6620c1bac3b0b2ac488406701f80e123c794c1afd"
BASE = "https://gitlab.joyfullee.me/api/v4/projects/83/packages/generic/joyride-basemap/" + VERSION
ROOT = Path("/data/maps")


def main():
    for directory in ("private", "public", "maps", "tmp"):
        Path("/data", directory).mkdir(mode=0o700, exist_ok=True)
    auth = json.loads(Path("/pull/.dockerconfigjson").read_text())["auths"]
    authorization = "Basic " + auth["registry.gitlab.joyfullee.me"]["auth"]
    ROOT.mkdir(exist_ok=True)
    for filename in ("region.pmtiles", "manifest.json"):
        destination = ROOT / (VERSION + (".pmtiles" if filename.endswith("pmtiles") else ".json"))
        if not destination.exists():
            request = Request(BASE + "/" + filename, headers={"Authorization": authorization})
            temporary = destination.with_suffix(destination.suffix + ".partial")
            with urlopen(request, timeout=120) as response, temporary.open("wb") as output:
                while block := response.read(1024 * 1024):
                    output.write(block)
            temporary.replace(destination)
    archive = ROOT / (VERSION + ".pmtiles")
    with archive.open("rb") as source:
        if hashlib.file_digest(source, "sha256").hexdigest() != CHECKSUM:
            raise ValueError("archive integrity failure")
    if not MapRelease.objects.filter(version=VERSION).exists():
        call_command("register_map", VERSION, archive.name, str(ROOT / (VERSION + ".json")))
    # A later explicit promotion is not reset on container restart.
    if not MapRelease.objects.filter(active=True).exists():
        call_command("promote_map", VERSION)
    print("Immutable regional basemap installed and registered")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Avoid urllib exception details or credential-bearing request objects in logs.
        print("Basemap bootstrap failed; inspect sanitized job state", file=sys.stderr)
        sys.exit(1)
