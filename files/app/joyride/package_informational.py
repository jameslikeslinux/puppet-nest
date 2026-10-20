"""Reproducibly package the approved public subset, never arbitrary tree files.

Usage: python package_informational.py /path/to/joyride /output/directory
The caller must independently verify the exact main CI and publication approval.
No credentials are read and no source repository is modified.
"""
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys

SOURCE = "73c0575179ab995979f9756c6be750f4903d4781"
PUBLIC = [
    "index.html", "pages/ride-001-cathedral-climb.html",
    "assets/site.css", "assets/home.js", "assets/avatar-fall.svg",
    "assets/wordmark-stack-fall.svg", "assets/joyride-paper.svg",
    "assets/hero-cathedral.jpg", "assets/hero-wisconsin.jpg",
    "assets/trace-r1.svg", "assets/trace-r2.svg", "assets/trace-r3.svg",
    "assets/profile-r1.svg", "assets/fonts/Anton.woff2",
    "assets/fonts/Inter-400.woff2", "assets/fonts/Inter-600.woff2",
    "assets/fonts/Inter-800.woff2", "assets/fonts/NotoSansMono-400.woff2",
    "assets/licenses/OFL-Anton.txt", "assets/licenses/OFL-Inter.txt",
    "assets/licenses/OFL-NotoSansMono.txt",
]


def package(repo, output):
    def source(path):
        return subprocess.check_output(["git", "-C", str(repo), "show", SOURCE + ":frontend/public/" + path])
    release = json.loads(source("release.json"))
    assert release["release"] == "luna-frontend-v6-2026-10-20-r4"
    output.mkdir(parents=True, exist_ok=True)
    parts = [{"source": SOURCE, "release": release["release"], "files": {}} for _ in range(2)]
    for path in PUBLIC:
        data = source(path)
        digest = hashlib.sha256(data).hexdigest()
        if digest != release["files"][path]:
            raise ValueError("approved release hash mismatch: " + path)
        part = 1 if path.startswith("assets/fonts/") else 0
        parts[part]["files"]["/" + path] = {"sha256": digest, "base64": base64.b64encode(data).decode()}
    for i, part in enumerate(parts):
        content = json.dumps(part, sort_keys=True, separators=(",", ":")) + "\n"
        if len(content.encode()) > 1024 * 1024:
            raise ValueError("ConfigMap size limit")
        (output / ("bundle-" + str(i) + ".json")).write_text(content)
    print(json.dumps({"source": SOURCE, "release": release["release"], "public_files": len(PUBLIC), "parts": len(parts)}))


if __name__ == "__main__":
    package(Path(sys.argv[1]), Path(sys.argv[2]))
