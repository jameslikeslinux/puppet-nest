// Owner viewer key bursts serialize once, never drop keys or retry uncertainty.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

async function run(failInput = false) {
  const listeners = {};
  const requests = [];
  const canvas = {addEventListener: (name, fn) => { listeners[name] = fn; }, focus() {},
    getBoundingClientRect: () => ({left: 0, top: 0, width: 800, height: 600}),
    getContext: () => ({drawImage() {}}), style: {}};
  const status = {textContent: ''};
  const refresh = {addEventListener() {}};
  const sandbox = {
    location: {hash: '#synthetic-window-capability'},
    document: {getElementById: id => id === 'view' ? canvas : id === 'status' ? status : refresh},
    AbortSignal, setInterval() {},
    Image: class {constructor() { this.width = 800; this.height = 600; } set src(value) { this.onload(); }},
    fetch: async (url, options) => {
      const body = JSON.parse(options.body);
      requests.push({url, options, body});
      if (failInput && body.command === 'input') throw new Error('Synthetic uncertain delivery');
      return {ok: true, json: async () => ({status: 'ok', png_base64: 'fixture'})};
    }
  };
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(path.resolve(__dirname, '../../../files/firefox-browser/window-viewer.js'), 'utf8'), sandbox);
  // Queue a key burst while the initial screenshot promise is still in flight.
  for (const key of 'abcdefghij') listeners.keydown({key, preventDefault() {}});
  await vm.runInContext('inputs', sandbox);
  const input = requests.filter(request => request.body.command === 'input');
  if (!failInput) {
    assert.equal(input.map(request => request.body.payload.key).join(''), 'abcdefghij');
    assert.equal(vm.runInContext('pending', sandbox), 0);
  } else {
    assert.equal(input.length, 1);  // No automatic replay or later buffered input.
    assert.equal(vm.runInContext('inputFailed', sandbox), true);
    listeners.keydown({key: 'z', preventDefault() {}});
    await vm.runInContext('inputs', sandbox);
    assert.equal(requests.filter(request => request.body.command === 'input').length, 1);
  }
  for (const request of requests) {
    assert.equal(request.options.credentials, 'omit');
    assert.equal(request.options.redirect, 'error');
    assert.equal(request.options.headers.Authorization, 'Window synthetic-window-capability');
    assert.equal(request.url, '/_nest/bridge/window/control');
    assert.equal(Object.hasOwn(request.body, 'scope'), false);
  }
}
(async () => { await run(); await run(true); console.log('Firefox window viewer regressions passed'); })().catch(error => { console.error(error); process.exitCode = 1; });
