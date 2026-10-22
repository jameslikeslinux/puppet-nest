# Firefox creation receipt and finite recovery repair

Status: source implementation tested locally and in disposable native Firefox;
not yet an installed production repair. Agent Request ^2085 owns follow-through.

## Observed incident and root cause boundary

The actual installed v3 controller at investigation time was image
`sha256:e86c476ae331d559f5cd2f2db6d16740e1ce4c5a645164f9e2b778bbc198adcb`,
with controller SHA256
`50c878d88eb1c28e0a9528b8ab8bb0e3bfe23b85e1cc9b189a54f08d3cb4a6e6`.
An actual request-bound status and acquire for `t_274a959c` succeeded against
that image. That does not recover the different `t_b184dfb4` reservation.
Engineering read-only journal inspection confirmed that the latter is still
`creating`, in the current epoch, with prior native windows but no context.
No private page content, input text or viewer capabilities are recorded here.

The proven recovery defects are independent of ^2060's session.new/overlay bug:

- `tabs` status allocated through acquire instead of observing the reservation.
- `tabs` recover reached acquire before rejecting the unsupported action. An
  unknown creation therefore failed in acquire on every attempt, never reaching
  any recovery operation.
- The private transport discarded the distinction between a correlated native
  rejection and a transport failure. The outer controller persisted a context
  only after the transport returned; caller interruption before that assignment
  left no durable receipt.
- Closing the observer after uncertainty prevented late results on that observer
  from being used. There is no native command replay/read-result API that can
  retrospectively prove an identity whose result was never retained.

The historical initiating native exception was scrubbed by the installed code.
It is not possible to establish from this journal whether the original create
was rejected, delivered before reply loss, or timed out without effect. This
repair does not invent that missing evidence or adopt a tree-difference window.

## Recovery contract

The resident transport invokes a private creation-only receipt callback on the
correlated native response before returning it. The callback fsyncs the exact
native context or an allowlisted pre-effect rejection. It never persists native
messages, stack traces, page fields or input replies. Reservation, receipt and
open-binding commits retain the existing atomic replace/directory-fsync journal.
The exclusive process lease and bounded controller/endpoint locks remain intact.

`tabs` status and recover are now nonallocating paths, before acquire. Recover
can verify a retained context only within its native generation and outside
pre-existing windows. Repeated calls never issue another create, click or send.
The returned `recovery` object has `scope_state`, `recovery_state`, `next_action`,
`retry_allowed: false` and `input_replay_allowed: false`.

- `not_needed`: no reconciliation needed; status did not create a window.
- `reconcile_available`: a retained creation context can be explicitly verified.
- `verified`: exact native identity verified; independently read back before input.
- `engineering_repair_required`: correlated no-effect create rejection, unresolved
  retained identity or terminal cleanup requires the existing engineering owner.
- `owner_reconciliation_required`: no retained creation reply, or lost native
  generation. Preserve windows; request one concrete scoped owner decision.

Exhausted paths set `automatic_recovery_exhausted: true`; they are not permission
for timer redispatch, new-window replacement or journal erasure. The actual
Hermes adapter makes at most one supported recover read after recognized native
or creation uncertainty, preserves the original error/outcome, and includes the
finite result. It never retries the failed action. Busy remains explicit
`FIREFOX_BUSY` / `not_started` and does not trigger uncertainty recovery.

A process death before any durable native receipt remains fundamentally
ambiguous. A native success response that was committed before caller death is
recoverable. A failed fsync is not proof of durable ownership after restart.
Neither tree subtraction nor URL/title similarity can establish provenance:
Joy may create unrelated windows outside the controller's lock.

Canonical terminal cleanup can reconcile an exact retained creation receipt and
then close only its owned window. A correlated pre-effect create rejection can
be tombstoned without closing anything. Unknown creation is never acknowledged
as closed. Conflicting terminal receipts, owner closure and foreign contexts
remain refused.

## Executed checks

Focused Python fixtures: 52 passed. Coverage includes native reply loss before
and after receipt commit, failed receipt fsync, caller cancellation, dead HTTP
client, native no-effect rejection, concurrent scope identity, generation fencing,
repeated status/recover, bounded busy/not_started, no input replay and exact
terminal-hook receipts. The new fixtures are in the existing CI window job.

All ten existing compatibility scripts passed, and the Node viewer regressions
passed. The initial local endpoint-script invocation inherited production v3
instead of CI's explicit v1; it failed its legacy-envelope assertion. Rerunning
with the declared CI environment `SECURE_BROWSER_CONTROL_MODE=firefox-ui-v1`
passed. No test was weakened for this environment mismatch.

`spec/app/hermes/firefox_creation_canary.py` ran in a network-disabled disposable
copy of the installed image with only the candidate source overlaid. Actual
native replies were used, not fabricated transport responses:

- Lost result before receipt: bounded owner-reconciliation result; three recover
  reads, no duplicate windows, owner preserved, unknown window not closed.
- Caller loss after receipt commit: same-generation exact identity verified by
  three recover reads; exact close and repeated terminal acknowledgement passed.
- Native invalid create type: actual protocol rejection classified not_started;
  three finite engineering-repair results; no created window and safe tombstone.

The full existing native window canary also passed with candidate source: singleton
session refusal, concurrent windows, shared synthetic login, multiline typing and
replacement without sends, duplicate-URL isolation, distinct screenshot pixels,
observer reconstruction, protected-input refusal, owner viewer/scroll isolation,
queries, stability/commerce compatibility and exact HTTP terminal acknowledgements.
These are disposable source-overlay receipts, not installed production parity.

## Remaining authoritative follow-through

Inspection of the actual installed broker identifies the indexed-request ingress
as `agent_request_broker/block_ingress.py::agent_request_block`, lines 108-118.
It directly ends non-owner technical waits in triage and writes a retry timestamp,
without requiring an executable existing-repair resolution. This is the actual
indexed path; do not mistake generic Hermes block routing for its implementation.
Hermes' `kanban_db_lifecycle.py::_recover_agent_owned_capability_failure` requires
durable budget progress before dispatcher recovery; source and installed hashes
matched for that module. The supporting broker checkout is an older unrelated
branch, so its absent split module is not evidence that the installed path is
absent from current authoritative source.

A browser adapter cannot safely change task claims/dependencies or decide owner
consent. Finite accountable routing must be repaired/tested in an isolated current
broker source phase, not bypassed with a Nest wrapper or DB write. Preserve exact
worker, owner-decision and dependency gates and stop unchanged obstacles rather
than introducing automatic retry loops. Inspect Hermes supporting code read-only;
only request another genuine source boundary if a proven kernel change is needed.

Then finish exact-head CI/MR, managed image build/pin, host adapter apply/service
refresh, and actual installed AR-bound workflow checks. The existing deployment
uses Recreate: do not restart Firefox merely to clear uncertainty. If activation
requires interruption, retain profile/journals, inspect pending actions and obtain
one scoped owner decision. No readiness message has been sent to Luna. Catalog
engineering remains with ^2080 and is not held behind this repair.
