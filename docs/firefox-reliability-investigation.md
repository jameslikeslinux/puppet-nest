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

Endpoint image verification subsequently exercised the actual image through a
TLS-verified localhost fixture and the shipped public adapter, with a
nonexistent kubeconfig and client subprocess execution forbidden. An initial
two-cycle run passed in 122.726 seconds with 29 operations and four surviving
tab identities. The expanded run completed 12 UI/read/release cycles through
926.909 seconds, but its final bridge-refresh setup failed, so it is not an
overall passing soak. The test had first mis-escaped the NUL process delimiter
and then assumed argv[0] was literally `python3`; the actual Gentoo executable
was `/usr/lib/python-exec/python3.14/python3`. This is a harness identification
failure, not evidence that Firefox restarted or the endpoint repair failed.

The repaired short rerun passed one complete cycle, native type/click,
protected-field redaction, action replay refusal, paginated source reads,
explicit bridge process replacement and a simulated endpoint outage in 89.321
seconds. It measured 25 public operations, mean 3.179 seconds and maximum 9.406
seconds. Firefox generation and all four surviving tab identities remained
unchanged across bridge replacement and outage. No production profile or PVC
was mounted, and the disposable browser exited through Ctrl+Q. This verifies
the isolated transport seam, not the real `browser.eyrie` deployment or
hours-long owner workflow reliability. Safe receipts are retained under
`build/firefox-reliability/endpoint-*.json`; raw rendered Secret manifests are
restricted and must not be attached as evidence.

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

### Installed endpoint activation and follow-up input regression

MR 311 merged at approved head `764aa3c8a0fd0f3e54d47cbdc957ee24202330ac`
as `dad475874b6cf38c1c2f293da2c0523682316f00` on 2026-10-19. The normal
Bolt code deployment, `hermes_firefox_bridge` tagged owl apply and
`nest::eyrie::ai::deploy_firefox` activation succeeded. Deployment generation
39 uses approved image digest
`sha256:f23cd9ea717dec6ae992eb539184d57cccf4d4357f22ff2c2302dc6e17239612`.
Workload and installed client hashes match the approved source. The same PVC
UID remains bound. Both tabs observed immediately before activation restored;
object identities changed with the authorized Firefox generation transition,
and old bindings remain uncertain rather than being silently reassigned.
Star's fresh runtime record was idle before refresh. Only the named Star and
Talon units received their supported SIGUSR1 drain/relaunch through Bolt;
both reached new PIDs and running state without a forced systemd stop.

The first installed endpoint-only canary passed one cycle and exact selector
multiline readback, then failed a query transport call during its second
cycle. Its HTTP status was not retained; the generic error does not establish
a browser crash, session exhaustion or a busy-lock refusal. Thirty subsequent
read-only queries passed. A separate installed rerun completed eight cycles
over 290.209 seconds, 111 operations, mean 2.613 seconds and maximum 9.505
seconds. Both owner-tab identities and Firefox generation stayed unchanged
across this run and a client-module reconnect. Client subprocess execution
was forbidden, kubeconfig nonexistent and TLS verified at `browser.eyrie`.
This is bounded endpoint acceptance, not resolution of the earlier failure
or of the original sustained-CPU incident.

That rerun also independently reproduced the newly reported coordinate-input
defect: typing two LF separators into an existing textarea did not add either
separator. The selector path preserved exact multiline text. This is a
separate proven input defect, not evidence that the preceding transport error
or earlier CPU incident has the same cause. The rerun's `passed` flag covers
its asserted endpoint scenarios; its explicit coordinate measurements are a
failing input result, not a green multiline acceptance claim.

The follow-up source repair delivers each X11 LF as explicit Shift+Return,
preserving blank/trailing lines without clearing fields or submitting a chat
composer. Default typing remains insertion. Explicit `mode=replace` is
restricted to a guarded v2 selector field and native Select All/Send Keys,
with the existing action reservation before selection or input. Locator and
coordinate replacement are rejected, protected fields retain their guard,
and an uncertain replacement cannot be replayed with a new delivery attempt.
The public adapter also retains only the numeric HTTP refusal status for
privacy-safe future diagnosis; it does not expose response bodies or retry.
This follow-up source is not part of the already activated exact build and
must not be described as installed until separately verified and authorized.

The follow-up isolated image also reproduced the intermittent selector refusal.
A failure-message-only fixture overlay captured matching generation and tab
name but a mismatching chrome URL: the expected fixture was `/cycle-0`, while
AT-SPI still reported `/survivor-0` after the native WebDriver handle scan had
returned to the correct tab. The pre-input guard correctly refused input.
A delayed-observation regression failed before the repair. Native mapping now
waits at most three seconds for the original generation, selected accessibility
object, title and URL to agree before element resolution; it observes only,
does not reselect/retry, and retains the final pre-input guard. Changed
generation or object regressions still fail closed. This establishes a causal
seam for this reproduced refusal, not the cause of every prior incident.

The final isolated real-image canary passed three cycles in 186.425 seconds,
63 operations, mean 2.875 seconds and maximum 8.847 seconds, with five surviving
tab identities and generation unchanged across bridge replacement and endpoint
outage. It verifies exact textarea replacement (including terminal LF), exact
coordinate multiline input, native rich-text interior paragraphs, replay
refusal and protected-field redaction. Rich-text terminal Enter serialized as
an additional final line in `innerText`; the fixture records interior paragraph
behavior separately and does not claim byte-exact rich-text terminal whitespace.

The tracked follow-up image soak completed twelve cycles in 553.304 seconds,
180 operations, mean 3.043 seconds and maximum 9.701 seconds. Four surviving
tab identities and browser generation were unchanged across bridge replacement
and endpoint outage. Native process exit was zero and the disposable container
was absent afterward. Its survivor documents were short; it did not establish
multi-long-document accessibility discovery.

The expanded harness independently reproduced coordinate-field disappearance
with three long survivor pages on that unchanged image. The snapshot contained
350 nodes, reported truncation and exposed no entry fields. A bounded AT-SPI
trace showed background internal frames and documents marked VISIBLE but not
SHOWING, while the active document had both states. The traversal nevertheless
read background descendants, and the prose inclusion rule accepted VISIBLE
text. Background prose therefore consumed the active page's observation budget.
This is a proven discovery defect, not a demonstrated cause of the original
sustained-CPU incident or the installed query transport refusal.

Traversal now prunes non-SHOWING internal frames and document roots before
descending or reading text. Chrome tab objects remain outside those boundaries
and are still enumerated; offscreen VISIBLE prose inside the SHOWING document
remains observable. Two new regressions failed before this change and pass
afterward. The identical long-survivor scenario passed with a read-only source
overlay: two cycles, 131.209 seconds, 50 operations, mean 2.519 seconds and
maximum 7.773 seconds, five surviving tab identities and unchanged generation,
including exact coordinate paragraphs and bridge replacement/outage. This is
overlay verification, not pristine-image or installed acceptance. The source
change was then built, smoke-tested and published through the normal rootful
Bolt build wrapper. The actual remote digest was read from the registry API,
pulled independently and checked for source parity across all five modules:
`sha256:13f1fee96d1ec597fff37f509ab4d2c96a9eae31f730b577c5a979984700a40f`.
The pristine rebuilt image passed the same long-survivor scenario in two cycles,
129.559 seconds and 50 operations, mean 2.489 seconds and maximum 7.725 seconds,
with four surviving identities and generation unchanged. Graceful fixture
disposal was verified after both runs. Exact-head CI and longer pristine-image
acceptance remain required before any further activation proposal. Failed
harness receipts are retained, not counted as passes.

- Repeated native WebDriver detach/reattach did not terminate the isolated
  browser or lose its tabs. This does not exclude every mixed-protocol race.
- An earlier generic 3000-message page did not reproduce missing chrome tabs. Its
  complete canary passed, with a maximum bridge-operation duration of 7.332
  seconds. A depth-first accessibility-budget hypothesis is therefore not
  established as the cause of that incident. The later multi-document discovery
  failure above is a separate, directly reproduced traversal-budget defect.
- ATK assertions, a defunct GPU process, high main-thread CPU and transport
  timeouts are separate observations, not interchangeable root causes.
- Kubernetes API transport intermittently timed out during both this isolated
  canary and ^1981's work. One canary's final output was lost to an exec read
  timeout; that run is not counted as passing. Later runs emit progress and
  persist bounded result JSON before returning.
- The original sustained-CPU incident remains causally unexplained. The source
  fixes and short soak do not establish hours-long Luna-workflow reliability.

## Installed follow-up and latency attribution — 2026-10-20

MR 321 subsequently merged at exact head
`7a5710eb710c83e341145071c601f0d0addb7d20`, with successful exact-head
pipeline 10562. Under the separately recorded maintenance authorization, normal
Bolt/Puppet/KubeCM activation installed the pinned follow-up image. Deployment
generation 40, zero pod restarts, unchanged Bound PVC and restoration of all
three preactivation owner-tab title hashes were verified. Star's named gateway
refresh completed. Talon's remaining named refresh was deferred because its
gateway still reported an active turn; installed files are not proof that the
old gateway process has loaded the updated schema.

Installed TLS-verified `browser.eyrie` acceptance completed 24 cycles in
1999.849 seconds and 336 operations, with client subprocess execution forbidden
and nonexistent kubeconfig. Exact textarea replacement, selector and coordinate
multiline input, replay refusal, protected-field redaction, long-document
discovery and controller reconnect passed. Owner identities and generation were
unchanged; fixture release completed without cleanup errors. The shared-browser
fixture pause then ended. These assertions do not close the original hang:
late-cycle duration increased substantially, and the original aggregate harness
did not attribute operation time. The historical unrecorded query refusal also
remains unclassified. A separate observed HTTP 409 during ongoing input was
positively identified as endpoint serialization, not a browser hang.

A pristine-image isolated diagnostic completed 32 long-survivor cycles in
1382.623 seconds and 440 operations. Maximum operation time was 11.269 seconds;
five surviving identities and generation were unchanged across bridge refresh
and outage. Graceful disposal was independently verified. That run did not
reproduce the installed late-cycle spikes, but operation times still increased
gradually. Bridge and controller timing fields place most of the observed
duration inside the bridge rather than outer HTTPS transit. This does not
identify the cause of the separate production spikes.

An explicitly labelled, fixture-only numeric profiling overlay then measured
493 snapshots in an eight-cycle run. Traversal size stayed bounded; large
snapshots visited 382–392 nodes. A typical snapshot nevertheless performed
roughly 9500 `gi.Repository.enumerate_versions` calls: `_state_names` required
the same static API once for every state of every node, and `_extent` repeated
that discovery. This is measured amplification in the controller, not proof
that it causes sustained CPU usage in Firefox.

The minimal source repair lazily caches only the static AT-SPI API per bridge
worker. Node states, text, geometry and ownership observations remain fresh.
The new regression failed before the repair with 36 version checks instead of
one; the eight focused suites now pass 99 tests. The existing text-interface
fixture was updated to stub the new API boundary without changing assertions.

The same instrumented eight-cycle scenario passed before and after the repair:
368.806 versus 254.777 seconds, 128 operations each, maximum 9.875 versus
7.006 seconds. Large-snapshot median was 0.484468 versus 0.224144 seconds.
These are sequential diagnostic runs, not a randomized benchmark; a surviving
blank tab differed between profiles. Both used read-only source overlays, not
rebuilt-image or installed acceptance. Crucially, gradual growth persists:
first/last twenty large-snapshot medians after the repair were 0.155446 and
0.327324 seconds. The static API cache is therefore an overhead reduction, not
a complete fix for that growth or the canonical reliability incident. Do not
roll out another image or reuse a consumed maintenance approval on this evidence
alone. Numeric receipts and diagnostic wrappers are retained under
`build/firefox-reliability/run11787-*`.

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

## Reproduced long-lived AT-SPI descriptor retention — 2026-10-20

The completed fixed-document diagnostic separates observer lifetime from page
growth. Forty snapshots in one observer stayed approximately flat within each
round (first/last ten medians 0.300673/0.302024 seconds, then
0.350370/0.349750 seconds). Fresh public workers between those rounds grew from
0.424968 to 0.460753 seconds, then 0.469175 to 0.509631 seconds. The full
fixture-only overlay run passed eight cycles and 208 public operations in
316.262 seconds. Generation and five surviving identities stayed unchanged;
graceful fixture disposal was independently verified. These are not installed
or pristine-image acceptance receipts.

Further controlled experiments narrow the trigger:

- Eighty API-import-only workers and eighty desktop-initialization-only workers
  did not materially increase fixed-document snapshot time: medians were
  0.194987, 0.197261 and 0.197638 seconds. Merely importing GI is not the cause.
- Eighty Firefox-root discoveries, without reading the document tree, increased
  median snapshot time from 0.193732 to 0.281922 seconds. Subsequent eighty-worker
  tree and snapshot phases increased it to 0.377590 and 0.475013 seconds.
- Numeric process sampling reproduced Firefox descriptor growth from 418 to
  646, 888 and 1083, while both D-Bus daemon descriptor counts stayed constant.
  Explicit `Atspi.exit()` and bounded client GLib event draining did not prevent
  growth. Neither workaround is included in source.
- A descriptor-type reproduction identifies retained `anon_inode:[pidfd]`
  handles: 195 before churn, 438 after eighty Firefox-root discoveries and 681
  after another eighty. Socket counts did not show the same retained growth.
  The fixture image contains AT-SPI 2.58.8, libdbus 1.16.2 and GLib 2.88.3.
- A bounded numeric syscall trace attached only to the disposable Firefox main
  thread shows `getsockopt(SO_PEERPIDFD)` during direct-client authentication.
  The trace decodes no received message payloads. It supports the descriptor
  attribution, not a claim that this exact trace reproduces the production hang.

The upstream AT-SPI 2.58.8 `atk-adaptor/bridge.c` retains each direct connection
in `spi_global_app_data->direct_connections` without the disconnected-client
removal filter present in current upstream source. Libdbus keeps process
credential descriptors with those connection objects. Relevant source:

- https://github.com/GNOME/at-spi2-core/blob/2.58.8/atk-adaptor/bridge.c
- https://github.com/GNOME/at-spi2-core/blob/main/atk-adaptor/bridge.c
- https://dbus.freedesktop.org/releases/dbus/dbus-1.16.2.tar.xz

The minimal launcher repair sets `ATSPI_DISABLE_P2P=1` before Firefox loads
atk-bridge. This disables advertisement of the leaking direct socket, not
accessibility or authentication: workers continue using the same private
desktop accessibility bus. Setting it only in the client is insufficient for
this image; its older client library does not implement the switch. The earlier
client-only experiment therefore does not test the server mitigation.

With the server switch on the unchanged image, eight public canary cycles and
128 operations passed, followed by two eighty-worker root-discovery phases.
Firefox pidfds stayed zero; total descriptors were 150, 150 and 151. Snapshot
medians stayed 0.222371, 0.221090 and 0.224248 seconds. The complete diagnostic
took 301.446 seconds and preserved five surviving identities across isolated
bridge refresh/outage. This explicitly labelled configuration/source-overlay
experiment is not rebuilt-image or production acceptance.

The shipped endpoint canary now has an opt-in `--observer-churn` regression
using real public snapshots and numeric-only disposable-browser descriptor
samples. Against the unchanged image, forty snapshots fail the regression:
pidfds rise from 141 to 261 and total descriptors from 355 to 471. With only
the repaired launcher overlaid, the same regression passes: pidfds remain zero,
total descriptors decrease from 216 to 207, and the full one-cycle canary
passes 77 operations in 129.445 seconds with five surviving identities. The
initial launcher-overlay attempt lacked executable permissions and failed
fixture readiness; the harness now copies it into its temporary directory with
the executable mode Puppet normally installs. That harness failure is not
counted as a browser regression or successful acceptance.

Reproduce against a verified immutable image, without an owner profile:

```sh
PYTHONDONTWRITEBYTECODE=1 SECURE_BROWSER_CONTROL_MODE=firefox-ui-v1 \
  build/firefox-reliability/venv/bin/python \
  spec/app/hermes/firefox_endpoint_canary.py \
  --image <immutable-local-image-id> --iterations 1 --long-survivors \
  --observer-churn 40 --output <receipt.json>
```

`--launcher-source files/firefox-browser/nest-firefox-browser.sh` explicitly
labels a source-overlay test; omit it for pristine rebuilt-image acceptance.
Only isolated infrastructure sampling/setup/cleanup uses Podman. Browser
operations still use the TLS-verified public adapter with nonexistent kubeconfig
and forbidden client subprocess execution. Generation, surviving-tab identity,
protected-control redaction, replay refusal, bridge refresh and endpoint-outage
checks remain in place. No automatic restart, descriptor-closing injection,
profile reset, recovery loop or broad permission change is introduced.

This is an isolated causal reproduction and passing mitigation for descriptor
retention and gradual latency growth. The historical sustained-CPU incident was
not traced at this seam, so it remains unproven whether it had the same cause.
Rebuilt-image parity, extended churn acceptance, exact final-head CI and any
newly authorized installed activation remain separate requirements. MR 329's
earlier static-cache head passed pipeline 10591; that does not certify later
launcher changes. Production has not been interrupted for this investigation.

## Selected-tab refusal after the descriptor repair — 2026-10-20

MR 329 was subsequently merged and installed under its exact approval. Its
installed acceptance completed 24 interaction cycles and 300 additional
snapshots, with fixture cleanup, preserved owner tabs and zero retained pidfds.
Those results do not cover the remaining Joyride selected-tab refusal. Joy
superseded prolonged soak gates with focused regression and quick installed
acceptance; do not launch further longevity certification as a completion gate.

A fresh installed `document.title` query still failed with “BiDi selected-tab
mapping is absent or ambiguous”. Read-only diagnostic metadata showed four UI
tabs and four native browsing contexts, exactly one selected UI tab and one
active native window. Three contexts matched the selected URL exactly; only
one of those three was natively visible. No URLs, titles, page contents,
credentials or profile data were persisted. This is duplicate-URL ambiguity,
not proof of a fresh Firefox hang or a client/gateway schema failure.

The old URL-only mapping cannot distinguish surviving duplicate tabs. The
repair narrows duplicate URL candidates to the one native visible document in
the one active native client window. It uses a fixed boolean visibility read
in an isolated BiDi sandbox, never a page title, strip index, workflow binding,
caller-supplied script or tab activation. Missing/ambiguous windows, malformed
visibility responses, multiple visible candidates and zero visible candidates
still fail closed. The existing post-read UI, generation and native-context
revalidation discards results if selection moves during observation. Uncertain
workflow bindings and action journals are neither repaired nor replayed.

The isolated public-endpoint regression now has `--duplicate-survivors`: three
equal-title/equal-URL fixture tabs survive while each selected tab is read.
The unchanged installed-image source fails at its second duplicate; overlaying
only the repaired adapter passes the one-cycle canary, including protected
input redaction, exact text pagination, replay protection, bridge refresh and
endpoint outage, without changing browser generation or survivor identities.
The first green receipt took 79.349 seconds and 40 public operations. It is
source-overlay evidence, not pristine-image or installed acceptance.

Reproduce with the command in the prior section, replacing the churn flags
with `--iterations 1 --duplicate-survivors`. For a labelled source-overlay
comparison add `--bidi-source files/app/hermes/secure_browser_bidi.py`; omit
all overlays for rebuilt-image acceptance. Focused source fixtures additionally
exercise equal-title/different-URL tabs, inactive/ambiguous windows, malformed
visibility, and stale selection. Required exact-head CI and a quick supported
installed query of the previously failing page remain mandatory. Deployment
of a new image needs its own coordinated interruption authorization; a gateway
refresh cannot fix the reproduced server-side URL ambiguity.
