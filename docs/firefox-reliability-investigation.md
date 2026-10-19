# Persistent Firefox reliability investigation — 2026-10-19

## Scope and current conclusion

This is the canonical shared-browser investigation for Agent Request ^1993.
It concerns `ai/deployment/firefox` at `browser.eyrie`, not Camofox. Source
repairs below address reproduced controller and restoration defects. They are
not proof that the sustained Firefox CPU/responsiveness incident is resolved.
Production installation and user-visible acceptance remain separate gates.

No owner profile files, cookies, vault state, chat exports or private page
screenshots were collected. Test profiles are empty ephemeral directories in
an isolated pod without the `firefox-profile` PVC. No production browser input,
restart or explicit binding recovery was performed by this worker. During the
resumed endpoint work, one insufficiently isolated red test invoked a real
status command through the old exec/source-overlay path. Status reconciliation
can mark PID-era bindings uncertain or prune expired state. No before-state
receipt exists, so this run cannot assert unchanged workflow bindings. It did
not send UI input or process termination, and no uncertainty was reversed or
owner tab rebound. Replacement rejection tests explicitly forbid transport and
subprocess dispatch, rather than trusting the guard under test to prevent it.

## Evidence and cross-incident timeline

- ^1980 repaired bounded source-text pagination and extraction of Firefox's
  chrome URL. Its initial evidence had a selected tab but an empty URL. That
  is distinct from a missing selected tab and did not establish a browser hang.
- ^1981 subsequently repaired controlled-field and address-bar input pacing.
  MR 306 contains source `304a8dcf004ccd7499bbac26412df38bade07f6f`.
- At 2026-10-19 16:59 UTC, the ^1981 checkpoint recorded pod
  `firefox-774b758c59-mb4l6`, UID
  `f7a09fcf-2fe3-421e-a99f-f898c3bac691`, Firefox PID 62, container restart
  count 2 and four visible tabs. A single acquisition failed after Ctrl+T;
  the independent bounded text query could not identify a selected visible
  tab. X11 still had one focused Navigator window. Main-thread CPU accumulated
  3.0 seconds in a 3.0-second sample. ATK text assertions were also present.
  Neither observation establishes the initiating cause.
- ^1981, not this request, owned the separately approved one-time recovery.
  Subsequent read-only pod metadata showed the same pod UID, restart count 3,
  previous container exit 143 at 17:03:41 UTC, and a new container start at
  17:03:42 UTC. That SIGTERM exit is operational containment, not evidence of
  an OOM or spontaneous crash. The retained last-state record is not a complete
  history of older exits. No OOM conclusion is drawn from unavailable history.
- The deployed image reference was
  `registry.gitlab.joyfullee.me/nest/tools/firefox@sha256:6aafb20e25d4b6abb20f2dce383255244e15d2bd3731cb64fce10eeb892f27e5`.
  The runtime platform image ID was
  `sha256:18e435b40fb13d23aeb00735558b451ecf3899a6ba84a4383f3518c5643cfe6d`.
  The same platform image was used by the isolated pod. Firefox reported
  version 157.0. Source data records image revision
  `a47b35eb1a0829c9e79d1c21670398a9c5fd2c18`.
- The image launcher matched source at investigation start, SHA256
  `e0e2a4c593550cc83a5619646d9efc7aa8ebd78dfa3503861d5d73f0ad555ece`.
  The image bridge was older, SHA256
  `74a79d76627fd0a066d3be0a447285fa7f2756c43a87af12b56bce8993b31ffb`.
  The installed authoritative Hermes bridge overlay matched source at start,
  SHA256 `aeeac0385f8b7048adb736745a78e374870739f4a74e911c5732d5460bfe16ae`.
  The overlay/image distinction is intentional; installed overlay parity and
  image parity must be reported separately.

## Reproduced defects and repairs

### Runtime control-plane coupling (additional owner steering)

After the initial isolated soak, the owner-visible Milk-V workflow reported
successful acquisition/navigation followed by selected-tab drift and then UI
exec timeouts. Another supported snapshot exposed a Kubernetes API timeout to
`172.21.255.255:6443`, while an independent infrastructure readiness check
returned `ok`. The shared pod still had the original UID/image, restart count 3
and container start at 17:03:42 UTC. MR 311 remained open and unmerged; the
reclaimed activation had not changed the production browser image.

This establishes an unwanted control-plane dependency, not the cause of every
prior CPU hang or tab loss. Endpoint regression tests failed against the old
adapter: absent kubeconfig prevented reads, a query loaded the cluster-backed
connector, and an endpoint outage still reached `kubectl`.

The revised transport sends fixed JSON commands to the TLS-verified origin
`https://browser.eyrie/_nest/bridge/v1`. It does not discover proxies, follow
redirects, inject source code, retry actions, invoke Kubernetes or fall back to
another browser. A separate scoped credential is encrypted in Hiera, mounted
as a Kubernetes Secret and installed only on explicitly configured Hermes
hosts. It is never a tool argument or printed diagnostic. The existing Kasm
UI route is unchanged; the guarded bridge rejects browser-origin requests,
WebSocket upgrades, unknown commands/fields and oversized requests. Raw BiDi,
WebDriver, filesystem and arbitrary-script APIs are not routed.

The server serializes the whole command, including local BiDi mapping,
read/revalidation and UI actions. A worker inherits the operation lock so an
HTTP-server refresh cannot permit another command to overlap a surviving
worker. A client disconnect does not replay or cancel its action; existing
workflow uncertainty and action-key journals remain authoritative. The HTTP
worker is bounded separately from Firefox. Neither endpoint outages nor bridge
failure restart Firefox or erase profile state. The server-side BiDi reader
uses only the loopback listener and has no Kubernetes transport fallback.
OAuth helper operations use the same adapter; their metadata query accepts
only fixed title/origin/path facts, never caller JavaScript.

Local endpoint tests use an actual HTTP listener for authentication, envelope
rejection and busy-lock behavior, with nonsecret fixture credentials. Their
mocked browser dispatch is not live-browser acceptance. The revised transport
still requires an isolated real-browser endpoint canary, rebuilt image parity,
exact-head CI and installed public-tool acceptance without Kubernetes client
credentials. The old image's soak is not counted as proof of the new transport.
The earlier exact-image approval must not be silently broadened to a different
image or additional shared-session restart.

### Asynchronous acquisition, not proof of a dead browser

The same-image empty-profile test reproduced the exact error:
`new Firefox tab was not visibly selected after Ctrl+T; refusing to claim or navigate another tab`.
The bridge tested accessibility immediately after XTest delivery. A delayed
selected-tab fixture also failed before the repair. The repair delivers one
shortcut, persists uncertainty before delivery, and polls within a bounded
observation window without sending it again. It requires the original browser
generation, one added tab and, when real object identities are present, all old
tabs plus exactly the newly selected blank tab. Ambiguity still fails closed.

### Two workflows could claim one blank handoff tab

Sequential acquires with different workflow IDs produced identical locators
for an already-owned blank tab. The regression failed before the change.
Acquisition now checks existing bindings before accepting a blank handoff tab;
otherwise it creates its own tab under the existing shared state lock. This
prevents a second workflow from silently claiming the first workflow's blank.

### PID-only generation and command-line process matching were insufficient

A PID can repeat after either a browser or container restart. The old
`pgrep -o -f` expression also selected a launcher/probe shell whose command line
contained the Firefox launch script. In the isolated reproduction, X11's
Navigator owner PID was 8726 while the regex selected 8659. Generation now
binds the single visible Navigator window's process to boot identity, PID
namespace inode and process start ticks. The emitted digest is opaque.
Locators use the same identity check. The PID-reuse regression distinguishes
two starts with the same PID.

A one-time format transition cannot safely reconstruct missing historic process
start information. Existing PID-era bindings therefore become uncertain on
installation; tabs and action journals remain intact. Coordinate that transition
with the active workflow. Do not silently rebind a same-title or same-index tab.
Later bridge refreshes use the stable process generation and do not invalidate
bindings when Firefox and its AT-SPI object identities survive.

### Restoration policy and explicit startup URLs

A preserved PVC alone does not request automatic session restoration. With the
old startup behavior, the isolated SIGTERM/restart test retained only a blank
tab instead of its three fixture pages. In a clean UI-quit test with explicit
restore preferences, all five existing tabs returned, but the launch argument
`about:blank` appended a sixth tab. Omitting that argument retained exactly five.

KubeCM now manages `browser.startup.page = 3` and
`browser.sessionstore.resume_from_crash = true`. The launcher omits a default
startup URL while preserving an explicitly configured URL. A same-image clean
quit test retained all four observed tabs; a separate checkpointed SIGTERM test
retained all five observed tabs. The latter waited 20 seconds for Firefox's
normal session checkpoint; it is not a guarantee for immediate unsaved state.
The launcher also waits for Firefox before tearing down its display and bus
when the launcher itself receives termination. No restart loop or force-kill
fallback was added.

These tests use explicit known preferences in isolated profiles. Validate the
actual enterprise-policy application in the final pinned workload as part of
installation acceptance; do not infer that result from the fixture preference.

### Accessibility interface calls and controller overlap

The old snapshot code called the Text interface on non-Text accessibles. The
isolated browser logs contained matching ATK assertions. Text calls now require
an advertised Text interface. This removes a demonstrated invalid API call; it
is not evidence that the assertions caused the sustained-CPU incident.

Complete supported operations now share a user-wide controller lock, rather
than letting a BiDi read/revalidation pair overlap a supported UI mutation from
another local Hermes profile. Busy callers fail after a bounded wait without
starting an operation. The pod state lock still protects workflow mutations.
This local lock is not a distributed lock for controllers on different hosts;
all supported participating runtimes must use the coordinated installed adapter.
Owner-driven manual selection is still detected by existing revalidation, not
prevented or treated as authorization to operate a different tab.

## Falsified or unresolved hypotheses

- Repeated native WebDriver detach/reattach did not terminate the isolated
  browser or lose its tabs. This does not exclude every mixed-protocol race.
- A generic 3000-message page did not reproduce missing chrome tabs. Its
  complete canary passed, with a maximum bridge-operation duration of 7.332
  seconds. A depth-first accessibility-budget hypothesis is therefore not
  established as the cause, and no speculative traversal rewrite was made.
- ATK assertions, a defunct GPU process, high main-thread CPU and transport
  timeouts are separate observations, not interchangeable root causes.
- Kubernetes API transport intermittently timed out during both this isolated
  canary and ^1981's work. One canary's final output was lost to an exec read
  timeout; that run is not counted as passing. Later runs emit progress and
  persist bounded result JSON before returning.
- The original sustained-CPU incident remains causally unexplained. The source
  fixes and short soak do not establish hours-long Luna-workflow reliability.

## Reproduction and measured verification

Artifacts for this run are under `build/firefox-reliability/` in the request's
isolated worktree. The pod manifest uses the production image digest, `emptyDir`
only, a separate app label, no Service/Ingress, and a sleep supervisor so tests
can stop their own launcher. It does not select or mount owner storage.

Focused regressions are in `spec/app/hermes/test_firefox_reliability.py` and
existing bridge/adapter suites. The new regression script is included in the
existing Secure browser fixtures CI job. `.gitlab-ci.yml` is already explicitly
unmanaged in `.sync.yml`.

The opt-in live-image harness is
`spec/app/hermes/firefox_reliability_canary.py`. It accepts a JSON stdin envelope
with keys `bridge`, `launcher`, `legacy`, `bidi`, `iterations` and optional
`message_nodes`, containing those exact checked-out source files. Invoke its
source using `python3 -c` in the isolated pod with:

- `NEST_ISOLATED_BROWSER_CANARY=t_06982fa3`
- `DISPLAY=:1`
- `PYTHONPATH=/tmp/canary-dependencies` for the isolated test's websockets wheel.

The runner uses the actual supported bridge command entrypoints in fresh
processes. Its reduced BiDi transport loads the shipped session methods and
bounded query code, not fabricated responses. It does not install Hermes or
claim that this is production public-tool acceptance. No caller page script is
accepted. The fixture's own button handler and nonsecret authentication cookie
are test data only.

One completed bounded soak before the final diagnostics-only edit reported:

- 12 repeated acquire/navigate/native type/replay/read/release cycles.
- 203.695 seconds, 136 bridge operations.
- Mean bridge operation 1.413 seconds; maximum 5.752 seconds.
- Five surviving tab identities unchanged throughout the non-restart portion.
- Exact filtered fixture-text SHA256
  `6610e51ecf6d8840dc6534eac261d789243e2c13b1e6a1080021359a45b85613`.
- Clean restart restored the same tabs and invalidated pre-restart bindings.

The final harness additionally verifies authentication after restart by making
an actual request to its dedicated fixture endpoint and checking only whether
the server received its known nonsecret fixture cookie. It never reads browser
cookies or profile content. Final run output and exact-head CI are reported
separately; the earlier short soak is not inflated into a long-duration claim.

Local commands:

```sh
pdk validate
SECURE_BROWSER_CONTROL_MODE=firefox-ui-v1 \
  SECURE_BROWSER_CONTROLLER_STATE_DIR="$PWD/build/firefox-reliability/controller-state" \
  build/firefox-reliability/venv/bin/python -m pytest -q \
  spec/app/hermes/test_firefox_reliability.py \
  spec/app/hermes/test_firefox_ui_bridge.py \
  spec/app/hermes/test_firefox_tab_ancestry.py \
  spec/app/hermes/test_secure_browser_text_reads.py \
  spec/app/hermes/test_secure_browser_firefox_ui.py \
  spec/app/hermes/test_secure_browser_bidi_ui.py \
  spec/app/hermes/test_secure_browser_general_hardening.py
sh -n files/firefox-browser/nest-firefox-browser.sh
git diff --check
```

The first inventory preflight from this worktree,
`bolt inventory show owl --detail --format json`, returned
`Could not find module ruby_task_helper containing task file task_helper.rb`.
The workspace had no `.modules`. Normal `bolt module install` populated the
project dependencies. Repeating inventory discovery and
`bolt command run 'id -un && hostname -f' --targets owl --stream` then returned
`joy` and `owl` successfully. No SSH or host-level deployment fallback was used.

## Safe diagnostics, reconnect and installation

1. Before recovering anything, retain pod UID, image reference and platform
   image ID, restart count, last exit reason/code/time, PVC identity and current
   participating controller revisions. Do not export environment secrets.
2. The bridge's engineering `diagnostics` command reads only the verified
   visible window's process identity, CPU ticks, thread count, resident pages
   and known image revision. It does not walk page content or profile files.
   Sample it twice with a bounded interval to distinguish CPU activity from a
   transport failure. Successful bridge replies include elapsed milliseconds;
   adapter replies include the sent overlay source SHA256 and controller time.
3. Reconnect the controller first. Do not restart Firefox just to refresh a
   bridge. Keep the same workflow ID and action keys. An uncertain input result
   must never be replayed with a new key to force delivery.
4. Expired or changed-generation bindings stay uncertain and preserve tabs.
   Explicit `tabs recover` abandons only the binding and preserves journals; it
   is not a browser restart or proof that the tab belongs to that workflow.
   Acquire a fresh blank handoff tab explicitly afterward. Never guess from
   title, strip index, URL alone, or a convenient native context.
5. Any browser-generation change requires independently authorized recovery.
   Prefer a clean UI quit when responsive. SIGTERM can only restore Firefox's
   saved checkpoints; unsaved form/editor content is not guaranteed. Never
   escalate to SIGKILL, reset a profile, delete a PVC or create a restart loop.
6. Before production apply, coordinate with ^1981 and other active users.
   Launcher/image and mounted-policy activation requires a shared-session
   interruption; it is not authorized merely because source work is authorized.
   The generation-format transition also requires coordinated binding handling.
7. Apply only through reviewed Nest/Puppet/KubeCM paths, pin the built image,
   verify its launcher and image bridge separately from the Hermes overlay,
   and exercise installed public tools on nonsecret fixture tabs. Confirm
   policy application, owner-tab retention and authentication continuity without
   reading private storage. Retain live rollout/acceptance evidence before
   declaring the request complete.
