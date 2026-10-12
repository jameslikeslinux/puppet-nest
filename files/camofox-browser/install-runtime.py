#!/usr/bin/env python3
"""Install the reviewed Camoufox engine, not the fetcher's floating latest."""

import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import urllib.request
import zipfile

VERSION = {"version": "135.0.1", "release": "beta.24"}
URL = (
    "https://github.com/daijro/camoufox/releases/download/v135.0.1-beta.24/"
    "camoufox-135.0.1-beta.24-lin.x86_64.zip"
)
SHA256 = "61e1ec455e021720af38a5cc5ff7566121363cb5b82b72f24e381ba2676a4888"
DEST = Path.home() / ".cache/camoufox"


def installed():
    try:
        return (
            json.loads((DEST / "version.json").read_text()) == VERSION
            and (DEST / "camoufox-bin").is_file()
            and (DEST / ".nest-runtime-sha256").read_text().strip() == SHA256
        )
    except (OSError, ValueError):
        return False


def main():
    if "--check" in sys.argv:
        return 0 if installed() else 1
    DEST.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="camoufox-", dir=DEST.parent) as tmp:
        archive = Path(tmp) / "runtime.zip"
        digest = hashlib.sha256()
        with urllib.request.urlopen(URL, timeout=60) as response, archive.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
        if digest.hexdigest() != SHA256:
            raise RuntimeError("Camoufox archive checksum mismatch")
        staging = Path(tmp) / "runtime"
        staging.mkdir()
        with zipfile.ZipFile(archive) as source:
            # Reject traversal even though the archive is checksum-verified.
            for member in source.infolist():
                target = (staging / member.filename).resolve()
                if not target.is_relative_to(staging.resolve()):
                    raise RuntimeError("Unsafe Camoufox archive path")
            source.extractall(staging)
        if not (staging / "camoufox-bin").is_file():
            raise RuntimeError("Camoufox archive lacks the expected executable")
        for path in staging.rglob("*"):
            path.chmod(0o755)
        (staging / "version.json").write_text(json.dumps(VERSION))
        (staging / ".nest-runtime-sha256").write_text(SHA256 + "\n")
        if DEST.exists():
            shutil.rmtree(DEST)
        staging.rename(DEST)
    return 0


if __name__ == "__main__":
    sys.exit(main())
