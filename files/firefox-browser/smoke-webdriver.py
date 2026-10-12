#!/usr/bin/env python3
"""Exercise real Firefox rendering, input, and tabs on the smoke Kasm display."""

import base64
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import time
import urllib.request

BASE = "http://127.0.0.1:4444"


def request(method, path, data=None):
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(
        BASE + path, data=body, method=method,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)["value"]


def main():
    with tempfile.TemporaryDirectory(prefix="nest-firefox-webdriver-") as tmp:
        with (Path(tmp) / "geckodriver.log").open("w") as log:
            driver = subprocess.Popen(
                ["geckodriver", "--host", "127.0.0.1", "--port", "4444"],
                stdout=log, stderr=subprocess.STDOUT,
            )
            session = None
            try:
                for attempt in range(60):
                    if driver.poll() is not None:
                        raise RuntimeError("geckodriver exited before readiness")
                    try:
                        request("GET", "/status")
                        break
                    except OSError:
                        time.sleep(0.5)
                else:
                    raise RuntimeError("geckodriver readiness timed out")
                session = request("POST", "/session", {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox",
                        "moz:firefoxOptions": {"binary": "/usr/lib64/firefox/firefox"},
                    }},
                })["sessionId"]
                path = f"/session/{session}"
                fixture = (
                    "data:text/html,<title>Nest browser smoke</title>"
                    "<input id='value'><button id='click' "
                    "onclick=\"document.title='Clicked'\">Click</button>"
                )
                request("POST", path + "/url", {"url": fixture})
                assert request("GET", path + "/title") == "Nest browser smoke"
                element_key = "element-6066-11e4-a52e-4f735466cecf"
                field = request("POST", path + "/element", {
                    "using": "css selector", "value": "#value",
                })[element_key]
                request("POST", path + f"/element/{field}/value", {"text": "nest-input-ok"})
                assert request("GET", path + f"/element/{field}/property/value") == "nest-input-ok"
                button = request("POST", path + "/element", {
                    "using": "css selector", "value": "#click",
                })[element_key]
                request("POST", path + f"/element/{button}/click", {})
                assert request("GET", path + "/title") == "Clicked"
                png = base64.b64decode(request("GET", path + "/screenshot"))
                assert png[:8] == b"\x89PNG\r\n\x1a\n"
                width, height = struct.unpack(">II", png[16:24])
                assert width >= 640 and height >= 400, (width, height)
                original = request("GET", path + "/window")
                tab = request("POST", path + "/window/new", {"type": "tab"})["handle"]
                request("POST", path + "/window", {"handle": tab})
                request("POST", path + "/url", {"url": "data:text/html,<title>Nest second tab</title>"})
                assert request("GET", path + "/title") == "Nest second tab"
                request("DELETE", path + "/window")
                request("POST", path + "/window", {"handle": original})
                assert request("GET", path + "/title") == "Clicked"
                print(f"Firefox on KasmVNC: navigation/input/click/tabs/PNG {width}x{height} passed")
            finally:
                if session:
                    request("DELETE", f"/session/{session}")
                driver.terminate()
                try:
                    driver.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    driver.kill()
                    driver.wait()


if __name__ == "__main__":
    main()
