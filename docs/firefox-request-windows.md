# Same-session request windows: implementation candidate

This is a prepared cutover, not a completed production rollout. The live
production mode remains `firefox-bidi-ui-v2` until the managed deployment is
explicitly authorized and applied. Source now pins the verified candidate image
and stages `firefox-windows-v3` for the browser and Owl's Talon/Star adapters.
Do not merge/apply this cutover without fresh exact session-interruption
authority. The existing owner session, uncertain drafts, and unrelated windows
must not be reset to activate it.

## Boundary

`firefox-windows-v3` keeps one Firefox process/profile/login session. The root
Kasm URL remains unchanged. Each authoritative `kanban:<board>:<task_id>` scope
gets one separately journaled native top-level window. Hermes derives scope
from dispatcher/session context, never a model-supplied workflow or scope.

The bridge retains a classic WebDriver session through a loopback-only
geckodriver service. Private BiDi observer sockets attach to that same session;
closing/reconnecting an observer does not create another native session or
change native context/window IDs. Persisted browser generation includes boot,
PID namespace, process ID and process start time. A browser/driver session loss
or an interrupted ambiguous creation preserves windows and refuses replacement,
rather than identifying them by URL/title or silently multiplying them.

The initial active owner window is reserved before creating agent windows.
Selected root tabs are resolved inside that window using isolated-realm native
visibility. Pre-existing unrelated windows are never acquired or closed.
Native page input and viewport capture address the bound context directly.
The v3 xmonad manage hook keeps new Navigator windows behind current focus;
legacy mode and transient dialog management remain unchanged.

The existing bridge route stays authenticated with verified TLS. Native
listeners are loopback-only, not Kubernetes Service ports. All commands are
fixed, bounded operations. Caller JavaScript, cookie/profile/storage export,
global screenshots, XTest input and global focus fallback are unavailable in
window mode. Old accessibility locators cannot cross into a different window.
Selectors, public input and viewport coordinates target only the bound window.

## Owner URL

A scoped response includes `owner_window_url`. The fragment is an unguessable
per-window capability; it is not the service credential and does not enter
HTTP URL logs or referrers. The owner viewer uses same-origin bounded JSON,
no cookies, no CORS and no credential discovery. It renders that context's
native viewport image and sends owner keyboard/pointer actions to that same
context. An agent cannot use the owner-input command through the agent bridge
command envelope. Agent typing into protected fields is refused.

The viewer intentionally does not claim to render Firefox extension chrome,
native browser/security dialogs or a whole isolated desktop. Those are a known
remaining capability boundary, not a reason to silently expose global Kasm
capture or global input as a scoped viewer. A shared-process Firefox hang can
still affect every window. Window isolation is not process/crash isolation.

## Input and retained uncertainty

The journal is persisted and fsynced before creation, input and close. Input
keys bind scope and an input digest; a changed payload under the same key is
rejected. Started/uncertain actions are never replayed. Legacy journal action
keys are fenced from reuse in a new window, without copying draft contents or
modifying the old journal. In particular,
`joyride-run11909-luna-test-rollback-type` remains unreplayed and uncertain.

Ordinary typing and explicit replacement use native key events with bounded
page event-loop yields. Continued entry preserves an already active field's
caret/selection rather than clicking its center again. Multiline editable fields
accept newline text using Shift+Enter; single-line fields, other control
characters and native special-key payloads remain refused. Shift+Enter is a
multiline gesture, not a universal guarantee about an application's key handler;
the original client must still verify its composer without authorizing Send.
Returned confirmation distinguishes exact native field
value/active-state/geometry readback from independent screenshot-text agreement:
`input_readback_confirmed` does not assert that screenshot text was matched.
The field value itself is not persisted in the action journal. The viewer queues
owner key bursts once and stops buffered input after an uncertain response.

## Canonical terminal close

The broker's existing terminal outbox uses the parent-decided contract:

    {"command":"window_lifecycle","payload":{"action":"close","scope":"kanban:<board>:<task_id>","terminal_event_id":123,"terminal_status":"completed"}}

The event number above is a schema example. Accepted statuses are exactly
`completed`, `cancelled`, `denied`, `superseded`. Scope/event/status receipts
are durable. Successful close is read back against the exact native window
before returning `closed: true`; replay returns `already_closed: true` only
for the retained exact terminal identity. An absent scope is tombstoned so a
late worker cannot create a new window after termination. Root closure and
conflicting terminal events are rejected. A foreign/unproven context moved into
an agent window causes preservation/refusal, not blanket closure.

Lease expiry, worker exit, retry, review, blocked/waiting state and the old
`release` operation are not terminal. They retain the working owner URL.
Broker delivery remains disabled until installation and exact acknowledgement
compatibility are verified. The broker source handoff is MR !191 in
`nest/hermes-agent-request-broker`, not a new browser implementation task.

## Executed checks

The focused Python browser fixtures and new window/HTTP fixtures pass, as do
Node viewer burst/error checks, shell/JavaScript syntax and `pdk validate`.
The new fixtures are included in exact-head CI. Native executable acceptance
is `spec/app/hermes/firefox_windows_canary.py`, run inside a disposable copy of
the installed Firefox image with no owner mounts and networking disabled.

The bounded native checks cover concurrent scopes, same-profile synthetic
login continuity observed by the fixture server (no cookie export), duplicate
URL input isolation, root preservation, distinct native screenshot pixels,
release/acquire without growth, observer reconstruction, protected agent input
refusal, owner HTTP viewport/input, and exact terminal close. They use the real
xmonad Full layout. The first observation found focus theft on window creation;
the mode-specific manage hook fixes that measured behavior. This is not a
reproduction or root-cause claim for the historical intermittent rendering hang.

Safe run receipts and native source hashes are retained under
`build/browser-repair/` in the assigned worktree. Source-overlaid disposable
checks are not an installed production image/version receipt.

## Remaining production obligations

Keep this candidate draft and v3 disabled until its focused exact-head CI is
verified and remaining compatibility work is resolved. The current agent-window
boundary conservatively refuses extra unproven contexts instead of selecting or
closing them. Native chrome/security UI is not rendered by the page viewer.
Paginated text continuation, application-stability waiting and commerce readback
are implemented on the resident route and pass bounded native checks. Stability
means unchanged bounded DOM observations, not application completion. Commerce
readback reuses the existing sanitized parser, with a native DOM source label.
Keep compatibility and privacy checks in the cutover verification rather than
silently treating native page capability as complete browser-chrome capability.

Then build/pin the source-managed image and host adapter, perform normal merge
and managed deploy/apply, obtain the usual fresh exact cutover authorization if
the singleton Recreate rollout will interrupt the owner session, and verify the
installed source hashes and broker close acknowledgement before enabling its
outbox. The managed image at source `3c112c8b7f3cc39e79276cb9bbef3ba9479d2a96`
passed the baked native canary, including multiline replacement/continued entry,
owner wheel isolation and exact HTTP close/replay receipts. Source pins its
verified remote digest:
`sha256:bb02076454cd67ef67178121483334e294758984c0a1b2aca0f8762eec84451c`.
Prove a working owner URL and bounded original-client Luna behavior
without replaying the retained uncertain draft, duplicating a chat, or waiting
for the whole Joyride application program. Historical-tab uncertainty remains
preserved; no prolonged hang reproduction or historical-tab acceptance ceremony
is an implementation prerequisite.
