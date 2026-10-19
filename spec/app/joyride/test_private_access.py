"""Exercise the real pinned nginx listener without cluster credentials.

Run with python3 spec/app/joyride/test_private_access.py. Requires Podman/OpenSSL.
Upstreams are explicit local fixtures, not substitutes for live app acceptance.
"""
import http.server
import json
from pathlib import Path
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import unittest
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
IMAGE = "docker.io/nginxinc/nginx-unprivileged@sha256:f5116ed4606f3eb015dd4a8e28cb9b351476dc0ad4bc6e9f93b19cec130cdf03"


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=60)


def unused_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class Upstream(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        status = 401 if self.path.startswith("/ops/") and not self.headers.get("Authorization") else 200
        self.send_response(status)
        self.end_headers()
        self.wfile.write(json.dumps({"path": self.path, "headers": dict(self.headers)}).encode())

    def log_message(self, format, *args):
        pass


class PrivateAccess(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix="joyride-private-access-")
        cls.path = Path(cls.directory.name)
        cls.path.chmod(0o755)
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.port = unused_port()
        cls.probe_port = unused_port()
        cls.container = "joyride-access-test-" + uuid.uuid4().hex[:12]
        config = (ROOT / "files/app/joyride/test-access-nginx.conf").read_text()
        for name, port in (("web", 8000), ("ops", 8001)):
            config = config.replace(f"joyride-test-{name}.test.svc.cluster.local:{port}", f"127.0.0.1:{cls.server.server_port}")
        config = config.replace("listen 8443", f"listen 127.0.0.1:{cls.port}")
        config = config.replace("listen 8080;", f"listen 127.0.0.1:{cls.probe_port};")
        (cls.path / "nginx.conf").write_text(config)
        run("openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=joyride-test.eyrie", "-addext", "subjectAltName=DNS:joyride-test.eyrie", "-keyout", str(cls.path / "tls.key"), "-out", str(cls.path / "tls.crt"))
        (cls.path / "tls.key").chmod(0o644)  # Disposable fixture, never a managed key.
        cls.context = ssl.create_default_context(cafile=str(cls.path / "tls.crt"))
        try:
            run("podman", "run", "-d", "--name", cls.container, "--network", "host", "--read-only", "--cap-drop=ALL", "--security-opt", "no-new-privileges", "--user", "101:101", "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m,mode=1777", "-v", f"{cls.path}/nginx.conf:/etc/nginx/nginx.conf:ro", "-v", f"{cls.path}:/tls:ro", "--entrypoint", "nginx", IMAGE, "-g", "daemon off;")
            for _ in range(50):
                try:
                    with socket.create_connection(("127.0.0.1", cls.probe_port), timeout=0.2):
                        break
                except OSError:
                    time.sleep(0.1)
            else:
                logs = run("podman", "logs", cls.container)
                raise RuntimeError(logs.stdout + logs.stderr)
        except Exception:
            subprocess.run(["podman", "rm", "-f", cls.container], capture_output=True)
            cls.server.shutdown()
            cls.directory.cleanup()
            raise

    @classmethod
    def tearDownClass(cls):
        run("podman", "rm", "-f", cls.container)
        cls.server.shutdown()
        cls.server.server_close()
        cls.directory.cleanup()

    def request(self, path="/", host="joyride-test.eyrie", sni="joyride-test.eyrie", extra=""):
        with socket.create_connection(("127.0.0.1", self.port), timeout=5) as raw:
            with self.context.wrap_socket(raw, server_hostname=sni) as sock:
                sock.sendall(f"GET {path} HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n{extra}\r\n".encode())
                data = b""
                while chunk := sock.recv(65536):
                    data += chunk
        return int(data.split(b" ")[1]), data

    def test_home(self):
        self.assertEqual(self.request()[0], 200)

    def test_exact_origin_with_standard_port(self):
        self.assertEqual(self.request(host="joyride-test.eyrie:443")[0], 200)

    def test_shared_ingress_host_is_not_forwarded(self):
        self.assertEqual(self.request(host="gitlab-test.eyrie")[0], 421)

    def test_host_suffix_is_not_accepted(self):
        self.assertEqual(self.request(host="joyride-test.eyrie.attacker.invalid")[0], 421)

    def test_wrong_port_is_not_accepted(self):
        self.assertEqual(self.request(host="joyride-test.eyrie:8001")[0], 421)

    def test_wrong_sni_fails_handshake(self):
        with self.assertRaises(ssl.SSLError):
            self.request(sni="gitlab-test.eyrie")

    def test_private_controller_is_absent(self):
        self.assertEqual(self.request(path="/delivery/queue")[0], 404)

    def test_roster_and_admin_are_absent(self):
        for path in ("/ops/roster", "/admin/", "/ops/arbitrary"):
            with self.subTest(path=path):
                self.assertEqual(self.request(path=path)[0], 404)

    def test_status_still_needs_application_auth(self):
        self.assertEqual(self.request(path="/ops/status")[0], 401)
        self.assertEqual(self.request(path="/ops/status", extra="Authorization: Bearer fixture-only\r\n")[0], 200)

    def test_forwarded_headers_are_replaced(self):
        status, data = self.request(extra="Forwarded: host=other.invalid\r\nX-Forwarded-Proto: http\r\nX-Forwarded-Host: other.invalid\r\nX-Forwarded-For: 1.2.3.4\r\n")
        self.assertEqual(status, 200)
        self.assertIn(b'"Host": "joyride-test.eyrie"', data)
        self.assertIn(b'"X-Forwarded-Proto": "https"', data)
        self.assertNotIn(b"other.invalid", data)
        self.assertNotIn(b"1.2.3.4", data)


class RouterBoundary(unittest.TestCase):
    def test_tailnet_grants_exact_destinations_only(self):
        policy = json.loads((ROOT / "files/tailscale/luna-gitlab.json").read_text())
        self.assertEqual(policy["acls"], [])
        self.assertEqual(policy["ssh"], [])
        self.assertEqual(policy["autoApprovers"], {})
        self.assertEqual(policy["grants"], [
            {"src": ["tag:luna-gitlab"], "dst": ["172.21.2.1/32"], "ip": ["tcp:22"]},
            {"src": ["tag:luna-gitlab"], "dst": ["172.21.1.3/32"], "ip": ["tcp:443"]},
        ])

    def test_firewalld_matches_tailnet_without_broad_accept(self):
        policy = ET.parse(ROOT / "files/tailscale/luna-gitlab.xml").getroot()
        self.assertEqual(policy.attrib["target"], "DROP")
        accepted = set()
        masqueraded = set()
        for rule in policy.findall("rule"):
            source = rule.find("source")
            target = rule.find("destination")
            assert source is not None and target is not None
            self.assertEqual(source.attrib["address"], "100.127.2.74/32")
            destination = target.attrib["address"]
            if rule.find("accept") is not None:
                port = rule.find("port")
                assert port is not None
                self.assertEqual(port.attrib["protocol"], "tcp")
                accepted.add((destination, port.attrib["port"]))
            elif rule.find("masquerade") is not None:
                masqueraded.add(destination)
            else:
                self.fail("Unexpected firewall rule")
        self.assertEqual(accepted, {("172.21.2.1/32", "22"), ("172.21.1.3/32", "443")})
        self.assertEqual(masqueraded, {"172.21.2.1/32", "172.21.1.3/32"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
