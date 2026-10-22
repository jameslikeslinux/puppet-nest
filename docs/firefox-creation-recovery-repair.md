# Firefox creation receipt and finite recovery repair

Status: browser source merged through Nest MR !449; authoritative broker source
merged through broker MR !197. Managed Firefox image published and pulled back;
production browser activation and installed acceptance remain pending. Agent
Request ^2085 owns follow-through.

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

## Integration continuation

Nest MR !449 merged as `12ae3513cf9a4742dc035050578b71720899d340` after
exact-head pipeline 11284 passed all required jobs at
`3265998926ab56d1e1da444a78218637220fcbb2`. The initial unit fixture fetch
failed with GitLab HTTP 503; the unrelated Joyride fixture teardown timed out
removing a disposable container. Both passed on a same-head retry without code
changes. Browser fixture jobs passed on the initial run.

Broker MR !197 merged as `1a2c24191dfc6d4a3119b6de467d61277c9532ca`
after exact-head pipeline 11291 passed. Bare indexed capability parking now
returns `capability_resolution_required`, preserving the live claim and original
run. The caller must bind an exact existing canonical repair prerequisite or
present a genuinely necessary typed owner decision; it cannot silently leave
triage residue or substitute an unchanged timer. Existing claim, actor, owner
grant and dependency gates remain authoritative. No Hermes core change was
necessary. This broker merge includes the sibling incidental-MR recovery pin;
the Nest activation advances that descendant without reverting sibling work.

Managed build command, from this task's isolated Nest worktree:

```sh
sudo -n env BOLT_CLEANUP_CMD='podman stop nest-firefox-ar2085 >/dev/null 2>&1' ./bin/bolt-wrapper plan run nest::build::firefox container=nest-firefox-ar2085 cpu=zen5 tag=ar2085-creation-32659989 registry=registry.gitlab.joyfullee.me build=true init=false deploy=true --stream
```

The isolated build container started from the installed immutable Firefox image,
with only build/cache mounts, not the owner profile. Puppet applied the candidate
controller, endpoint and private transport; the standard Firefox/Kasm smoke check
passed before publication. Remote pull-back confirmed:

- Image: `registry.gitlab.joyfullee.me/nest/tools/firefox@sha256:1f5335471cd08b7c54260cf9da7c3b477914fa95ca4688c56548373ec34c5cf4`.
- Image config: `942389ed0a3762f92b603f4a6d7571aa905f24355405d99ae769ae39dad97be2`.
- Controller: `7cb782971c60b05b9c6170976253bde3c8264c0d690c4a5f4cf5151bc6a311aa`.
- Endpoint: `2f5d42e45348ce38463f3465bf374914c448dc0b5e3ed68663fde77e1d232901`.
- Private transport: `05b70052faf05895187716df21410719b3e46b4c8a8926cf22c90fb943cdc630`.

The initial inventory smoke lacked the worktree's `ruby_task_helper` module.
`bolt module install` populated project dependencies; the exact inventory-backed
smoke then passed as `joy` on `owl`. This was not an SSH transport blocker and no
direct SSH or ad-hoc host Puppet fallback was used. Managed `nest::puppet::deploy`
and the tagged `nest::puppet::run` path perform host activation.

Fresh production journal inspection found owner and two known request windows
open, plus ^2080's `creating` reservation without a context. All recorded input
actions were delivered; none was pending/uncertain at that observation. Those
facts do not identify the unknown creation or authorize its closure. The current
image is unchanged. A singleton Recreate rollout would interrupt the owner and
invalidate native generation bindings; preservation and explicit reconciliation
must be scoped before activation. No readiness notification has been sent and no
installed browser acceptance is claimed.
