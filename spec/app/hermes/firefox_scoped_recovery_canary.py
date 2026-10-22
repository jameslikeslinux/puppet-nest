"""Disposable native fixture only: current-session refresh and retired recovery.

The retirement journal is fixture setup, not a claim that live generation
reconciliation occurred. No owner mounts, external network or active AR claims.
"""
import hashlib
import json
import os
from pathlib import Path
import runpy
import socket
import sys
import time
import urllib.request

sys.path.insert(0, '/opt/nest/firefox/bin')
from firefox_windows import Windows


def call(command, payload):
    token = Path(os.environ['FIREFOX_BRIDGE_TOKEN_FILE']).read_text().strip()
    request = urllib.request.Request('http://127.0.0.1:8766/_nest/bridge/v1',
        data=json.dumps({'command': command, 'payload': payload}).encode(),
        headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token})
    with urllib.request.urlopen(request, timeout=10) as reply:
        return json.load(reply)


deadline = time.monotonic() + 40
while True:
    try:
        for port in (9222, 4444, 8766):
            with socket.create_connection(('127.0.0.1', port), timeout=1):
                pass
        break
    except OSError:
        if time.monotonic() >= deadline:
            raise
        time.sleep(.2)
time.sleep(2)  # Disposable extension first-run only.
assert call('status', {'scope': 'owner'})['status'] == 'ok'
fixture = Windows('/home/kasm-user/.local/state/nest-firefox-ui/windows.json')
tree = fixture._tree()
for extra in tree[1:]:
    fixture._call('browsingContext.close', {'context': extra['context'], 'promptUnload': False})
fixture.browser.close()
owner = call('tabs', {'action': 'acquire', 'scope': 'owner'})
assert owner['status'] == 'ok', owner
B = 'kanban:canary:t_retired'
C = 'kanban:canary:t_fresh'
assert call('tabs', {'action': 'acquire', 'scope': B})['status'] == 'ok'
state_dir = Path('/home/kasm-user/.local/state/nest-firefox-ui')
path = state_dir / 'windows.json'
state = json.loads(path.read_bytes())
original_owner = state['windows']['owner'].copy()
original_controller = state['controller'].copy()
old_B = state['windows'][B].copy()
original = path.read_text()
digest = hashlib.sha256(original.encode()).hexdigest()
history = state_dir / 'generation-history'
history.mkdir(mode=0o700)
archive = history / (digest + '.json')
archive.write_text(json.dumps({'journals': {'windows.json': original}}))
archive.chmod(0o400)
original_archive = archive.read_bytes()
state['reconciliation'] = {'scope': 'kanban:canary:t_acceptance', 'epoch': original_controller['epoch']}
state['windows'][B] = {'state': 'retired', 'archive': archive.name}
path.write_text(json.dumps(state))  # Explicit isolated fixture setup, never live.
refresh = runpy.run_path('/canary/firefox-controller-refresh', run_name='fixture_refresh')
sources = {name: Path('/opt/nest/firefox/bin', name).read_text() for name in refresh['ASSETS']}
refresh['resident']({'sources': sources, 'expected_generation': original_controller['epoch'],
    'expected_source': hashlib.sha256(sources['firefox_windows.py'].encode()).hexdigest(),
    'scope': B, 'approval_id': 'apr-disposable-fixture-only'})
assert archive.read_bytes() == original_archive
assert call('tabs', {'action': 'acquire', 'scope': C})['status'] == 'ok'
assert call('tabs', {'action': 'acquire', 'scope': B})['status'] == 'ok'
after = json.loads(path.read_bytes())
assert after['windows'][B]['window'] != old_B['window']
assert after['controller'] == original_controller
assert after['windows']['owner'] == original_owner
new_B = after['windows'][B].copy()
assert call('tabs', {'action': 'acquire', 'scope': B})['status'] == 'ok'
assert json.loads(path.read_bytes())['windows'][B] == new_B
engine = Windows(path)
tree = engine._tree()
assert any(c['context'] == old_B['context'] for c in tree)
assert any(c['context'] == new_B['context'] for c in tree)
assert archive.read_bytes() == original_archive
print(json.dumps({'status': 'ok', 'native_session_unchanged': True, 'owner_binding_unchanged': True,
    'fresh_scope_acquired': True, 'retired_scope_new_binding': True, 'repeat_acquire_same_binding': True,
    'old_unknown_window_preserved': True, 'archive_unchanged': True, 'fixture_only': True}))
