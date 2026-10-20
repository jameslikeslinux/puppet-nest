"""Read-only approved Joyride informational frontend; no application imports.

The immutable bundle contains only explicitly selected release-hashed public
files. No database, private storage, session, mail or payment integration exists.
"""
import base64
import hashlib
import json
import mimetypes
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import cast
from urllib.parse import urlsplit

ROOT = Path(os.environ.get("JOYRIDE_INFO_BUNDLE", "/site"))
SOURCE = "73c0575179ab995979f9756c6be750f4903d4781"
CSP = "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'"


def load_files(root):
    files = {}
    for part in sorted(root.glob("bundle-*.json")):
        bundle = json.loads(part.read_text())
        if bundle["source"] != SOURCE:
            raise ValueError("informational source mismatch")
        for path, item in bundle["files"].items():
            if path in files or not path.startswith("/") or ".." in path:
                raise ValueError("invalid or duplicate public path")
            data = base64.b64decode(item["base64"], validate=True)
            if hashlib.sha256(data).hexdigest() != item["sha256"]:
                raise ValueError("public file hash mismatch")
            files[path] = data
    if "/index.html" not in files or len(files) != 21:
        raise ValueError("incomplete informational bundle")
    return files


class PublicServer(ThreadingHTTPServer):
    public_files: dict[str, bytes]


class Handler(BaseHTTPRequestHandler):

    server_version = "Joyride"
    sys_version = ""

    def log_message(self, format, *args):
        # Do not capture queries, cookies, caller identity or supplied tokens.
        pass

    def reply(self, status, data=b"", content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Security-Policy", CSP)
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Joyride-Source", SOURCE)
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        if self.command != "HEAD":
            self.wfile.write(data)

    def do_GET(self):
        host = self.headers.get("Host", "")
        if host not in ("joyride.eyrie", "joyride.eyrie:8000"):
            return self.reply(421)
        path = urlsplit(self.path).path
        # No URL decoding or filesystem lookup: encoded/private paths cannot
        # escape the literal allowlist. Query strings never select other files.
        if path in ("/health/live", "/health/ready"):
            return self.reply(200, b'{"status":"ready","mode":"informational","payments":"disabled","signup_enabled":false}\n')
        aliases = {"/": "/index.html", "/pages/ride-001-cathedral-climb": "/pages/ride-001-cathedral-climb.html"}
        path = aliases.get(path, path)
        if path in ("/sign-in", "/sign-in.html", "/signup", "/checkout-return", "/checkout-return.html"):
            return self.reply(503, b'{"error":"signup_disabled"}\n')
        data = cast(PublicServer, self.server).public_files.get(path)
        if data is None:
            return self.reply(404)
        content_type = mimetypes.guess_type(path)[0] or "application/octet-stream"
        return self.reply(200, data, content_type)

    do_HEAD = do_GET

    def do_POST(self):
        return self.reply(405, b'{"error":"informational_only"}\n')

    do_PUT = do_POST
    do_PATCH = do_POST
    do_DELETE = do_POST
    do_OPTIONS = do_POST


def main():
    server = PublicServer(("0.0.0.0", 8000), Handler)
    server.public_files = load_files(ROOT)
    server.serve_forever()


if __name__ == "__main__":
    main()
