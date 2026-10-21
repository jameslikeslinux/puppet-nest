'use strict';
// Fragment capabilities never enter access logs or referrers. No cookies,
// storage, clipboard export, bridge credential, or native endpoint in this UI.
const capability = location.hash.slice(1);
const canvas = document.getElementById('view');
const statusLine = document.getElementById('status');
let busy = false;
let pending = 0;
let inputs = Promise.resolve();
let inputFailed = false;
async function call(payload) {
  const response = await fetch('/_nest/bridge/window/control', {
    method: 'POST', headers: {'Content-Type': 'application/json', 'Authorization': 'Window ' + capability},
    body: JSON.stringify(payload), credentials: 'omit', cache: 'no-store', redirect: 'error',
    signal: AbortSignal.timeout(15000)
  });
  if (!response.ok) throw new Error('Window unavailable; refresh cannot replay input.');
  const reply = await response.json();
  if (reply.status !== 'ok') throw new Error('Window operation uncertain. Do not repeat input.');
  return reply;
}
async function refresh() {
  if (busy || pending) return;
  busy = true;
  try {
    const reply = await call({command: 'screenshot'});
    const image = new Image();
    await new Promise((resolve, reject) => {
      image.onload = resolve; image.onerror = reject;
      image.src = 'data:image/png;base64,' + reply.png_base64;
    });
    canvas.width = image.width; canvas.height = image.height;
    canvas.style.maxWidth = '100%';
    canvas.getContext('2d').drawImage(image, 0, 0);
    if (!inputFailed) statusLine.textContent = 'Connected to the exact request window. Click the page to interact.';
  } catch (error) { statusLine.textContent = error.message; }
  finally { busy = false; }
}
function input(payload) {
  if (inputFailed || pending >= 128) {
    statusLine.textContent = 'Input paused. Check the window before continuing.';
    return;
  }
  pending++;
  inputs = inputs.then(async () => {
    if (inputFailed) return;
    try { await call({command: 'input', payload}); }
    catch (error) { inputFailed = true; statusLine.textContent = error.message; }
  }).finally(() => { pending--; if (!pending && !inputFailed) refresh(); });
}
canvas.addEventListener('click', event => {
  canvas.focus();
  const rect = canvas.getBoundingClientRect();
  input({kind: 'pointer', x: (event.clientX - rect.left) * canvas.width / rect.width,
    y: (event.clientY - rect.top) * canvas.height / rect.height});
});
canvas.addEventListener('keydown', event => {
  // No global keyboard shortcuts or paste transport. Owner types directly;
  // native browser/security dialogs remain an explicit unsupported boundary.
  if (event.ctrlKey || event.metaKey || event.altKey || event.isComposing) return;
  if (event.key.length === 1 || ['Enter', 'Tab', 'Backspace', 'Escape', 'Delete', 'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) {
    event.preventDefault(); input({kind: 'key', key: event.key});
  }
});
document.getElementById('refresh').addEventListener('click', refresh);
refresh();
setInterval(refresh, 2000);
