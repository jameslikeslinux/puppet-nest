"""Exercise the real informational HTTP handler and release boundary."""
import hashlib
import http.client
import importlib.util
import json
from pathlib import Path
import threading

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("info", ROOT / "files/app/joyride/informational_site.py")
assert spec is not None and spec.loader is not None
info = importlib.util.module_from_spec(spec)
spec.loader.exec_module(info)


def main():
    files = info.load_files(ROOT / "files/app/joyride/informational")
    assert len(files) == 21
    assert hashlib.sha256(files["/index.html"]).hexdigest() == "893a95c439ee5103c10038d923ed9111248265d66b75a3a0f1f6d2568ac009c8"
    assert all(not any(s in p for s in ("member", "wmata", "mp4", "sign-in", "checkout", ".gpx")) for p in files)
    server = info.PublicServer(("127.0.0.1", 0), info.Handler)
    server.public_files = files
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    checks = 0
    try:
        def request(path, method="GET", host="joyride.eyrie"):
            connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=5)
            connection.request(method, path, headers={"Host": host})
            response = connection.getresponse()
            result = (response.status, response.read(), dict(response.getheaders()))
            connection.close()
            return result
        for path, data in files.items():
            status, actual, headers = request(path)
            assert status == 200 and actual == data, path
            assert "connect-src 'none'" in headers["Content-Security-Policy"]
            checks += 1
        assert request("/")[1] == files["/index.html"]
        assert request("/pages/ride-001-cathedral-climb")[1] == files["/pages/ride-001-cathedral-climb.html"]
        for path in ("/ops/status", "/admin/", "/api/me", "/api/routes", "/api/billing/checkout", "/api/waiver", "/delivery", "/member/ride-001-cathedral-climb", "/private/probe.gpx", "/assets/../member/x", "/%2e%2e/index.html", "/assets/clip-test-cathedral-pan.mp4", "/release.json"):
            assert request(path)[0] == 404, path
            checks += 1
        for path in ("/sign-in", "/signup", "/checkout-return"):
            assert request(path)[0] == 503
            checks += 1
        for method in ("POST", "PUT", "PATCH", "DELETE", "OPTIONS"):
            assert request("/", method=method)[0] == 405
            checks += 1
        assert request("/", host="joyride-test.eyrie")[0] == 421
        assert request("/", host="evil.invalid")[0] == 421
        assert request("/", method="HEAD")[1] == b""
        health = json.loads(request("/health/ready")[1])
        assert health["payments"] == "disabled" and health["signup_enabled"] is False
        print(json.dumps({"file_and_gate_checks": checks, "health": health, "source": info.SOURCE, "result": "passed"}))
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == "__main__":
    main()
