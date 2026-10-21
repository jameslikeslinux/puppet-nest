# Shared Firefox protocol ownership repair

## Observed cause and routing

The incident in Agent Request ^2060 is a mixed installed-client problem, not a
claim that independent browser windows provide independent protocol sessions.
At investigation start, production `ai/deployment/firefox` used image
`sha256:bb02076454cd67ef67178121483334e294758984c0a1b2aca0f8762eec84451c`.
Its private geckodriver reported `Session already started`; its retained resident
controller generation was resumable. The host's active adapter was instead the
old fork implementation, SHA256
`b6f06c88509f4f57b9759248d28a76b8e8892694bdf2328cf916bf9090edf6b1`.
It had no `CONTROL_MODE`, used Kubernetes port forwarding, and attempted its own
`session.new`. Its status returned shopping metadata and a single-tab policy.
These were real legacy operations, not merely incorrect diagnostic labels.

The host source checkout moved to Hermes commit
`099106edc1c799693fa92fb4f3965ee45b4f953a` at the adapter's modification time.
The adapter is a tracked fork file overlaid by Nest. Previously, selecting only
Puppet's `hermes_source` tag updated the checkout without selecting the overlay.
The durable fix adds that tag to the browser overlay and deprecated-file
removals, retaining their ordering after the checkout. This explains how a
source-only update can reintroduce the incompatible client. The exact historical
command that performed this checkout was not captured by this investigation.

The existing subscribed gateway/dashboard refresh resources also carry these
tags, so an overlay change refreshes importing services in the same managed
transaction. This uses the existing serialized/debounced service-refresh helper,
not forced reclaim of independent healthy Agent Request workers. A running one-shot worker
that already imported the old module remains old until that process exits;
fresh installed-process checks are distinguished from its cached tool results.

Pattern Kit's workbench is a separate pod with its own loopback Firefox and
`firefox-bidi-ui-v2`. Its source `session.new` is not evidence that it accesses
the production secure-browser listener. It is not changed by this repair.
OAuth helpers route through `tools.secure_browser_tool`; they must use the same
current adapter. Ordinary agent control uses verified HTTPS at `browser.eyrie`,
not cluster credentials, exec, or port forwarding. Cluster inspection/build and
managed deployment remain engineering operations, not browsing fallbacks.

## Supported concurrency contract

There is one persistent Firefox process/profile and one bridge-owned classic
WebDriver session. Per-request windows are context bindings inside that session.
The existing bridge has an exclusive process-level journal lease. HTTP API
requests use its process-safe endpoint lock; owner-viewer and API operations
also share a bounded reentrant controller lock. Busy refusal means no operation
started. There is no automatic transport retry.

The private BiDi connector attaches to the classic session's exact retained
loopback endpoint. Reconnecting an observer is not `session.new`. Closing an
observer must not send `session.end`. The connector serializes request IDs and
replies, closes idempotently, and closes on constructor cancellation. Kernel
socket/lock cleanup after process death does not end the classic session.
The legacy host bridge/session constructors refuse acquisition in v3; the
in-workload connector also refuses standalone session creation in v3.

Status is a protocol observation, not window allocation. It reports transport,
adapter and controller source identities, session ownership and scope state.
Owner tabs and unallocated request scopes are not mutated by status.

## Recovery and action uncertainty

- Busy: `FIREFOX_BUSY`, outcome `not_started`. No browser command was delivered.
- Transport/native failure: `FIREFOX_NATIVE_OUTCOME_UNCERTAIN`, outcome
  `uncertain`. Preserve the action key; independently read back before more
  input. Do not retry a Send/click under a new key.
- Lost controller generation: `FIREFOX_IDENTITY_LOST`. Preserve windows. Do not
  end an arbitrary session, create a replacement session, or infer ownership
  from URL/title.
- Window creation: persist the returned native context immediately, before the
  following tree read. Recovery may reconcile only this retained identity,
  within the same generation and outside the recorded pre-creation windows.
  Tree polling is bounded and never repeats the create operation.
- If creation returned no retained native identity, report
  `FIREFOX_CREATION_UNCERTAIN`. Preserve the unproven window and ask for explicit
  recovery; do not adopt a same-title/URL tab or silently create another window.
- Worker exit, cancellation, waiting or lease expiry is not a terminal event.
  The canonical terminal hook retains exact scope/event/status closure receipts.

During the first old-controller request-bound status check in this investigation,
`t_abc44cf8` became `creating` without a retained native context. That acquisition
was not replayed or guessed. A read-only root HTTPS status subsequently succeeded.
The old controller's generic failure did not expose the underlying exception,
so the precise cause of that acquisition failure is not established. This is a
separate observed recovery/diagnostic gap, not evidence that the legacy session
conflict caused the graphical creation failure. No Luna message was sent here.

## Executed checks and deployment boundary

A managed `nest::puppet::run` with `hermes_firefox_bridge` restored the current
host adapter without restarting Firefox. Its readback SHA256 matched Nest's
pre-repair adapter source:
`3944b4773a7730977fea93230a1d1c7f5efd20ed5866a276c87e03bf3b3e4231`.
This repaired routing drift but is not proof that already-imported clients have
reloaded, or that this repair's new image is installed.

The regression suite includes concurrent distinct scopes, exact generation
resume/refusal, process-death lease release, observer serialization and no
session creation/end, cancellation/timeout cleanup, read-only status, source-only
overlay selection, creation-response/read-failure reconciliation, and busy versus
uncertain delivery without replay. Selected new regressions fail against the
unchanged baseline. Compatibility scripts and the owner-viewer JavaScript suite
also pass locally. Raw fixture receipts are retained in the task's `build/`
workspace; no profile, cookie, token or private page content is a deliverable.

The disposable native image canary explicitly attempts a competing independent
`session.new` after acquiring the resident classic session. It must receive
Firefox's `Maximum number of active sessions` refusal and then prove the existing
resident session still operates. Its subsequent checks use concurrent scopes,
real typing/replacement, native screenshots, queries, observer reconstruction,
owner preservation and exact terminal closure. This is a deterministic protocol
reproduction, not a long graphical-hang soak.

The source-managed Bolt build and publish succeeded. The exact remote digest
was pulled back successfully:
`sha256:e86c476ae331d559f5cd2f2db6d16740e1ce4c5a645164f9e2b778bbc198adcb`.
Its native canary passed, including the competing-session refusal, concurrent
window creation, unchanged owner focus, typing/replacement without sends,
distinct screenshot pixels, repeated observer reconnection and terminal
close/readback. The initial disposable run failed because its exec environment
lacked `DISPLAY`; rerunning in a fresh disposable container with `DISPLAY=:1`
passed. This did not touch production state. Local focused fixtures passed,
as did all ten compatibility scripts, Node viewer checks and `pdk validate`.
Five selected new regressions failed against the unchanged baseline.

Baked controller SHA256:
`50c878d88eb1c28e0a9528b8ab8bb0e3bfe23b85e1cc9b189a54f08d3cb4a6e6`.
Baked endpoint SHA256:
`4799848a97affeba6af40b0bacc85d6f2a9c2d051296252ee2b4987a98b935a7`.

Build publication alone does not activate production. Managed activation must
retain the profile PVC and account for owner interruption and unresolved native
identities. The normal deployment is Recreate; never restart the whole browser
merely to clear a client protocol failure. Installed acceptance still requires
exact image/source readback and an actual request-bound bounded workflow. A
successful interactive root status or disposable canary alone is insufficient.
