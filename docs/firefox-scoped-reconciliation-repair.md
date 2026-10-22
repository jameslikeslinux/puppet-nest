# Per-binding Firefox reconciliation correction

Request ^2100 / task t_6b9d4bf4.

The previous global `state.reconciliation` admission check admitted only the
owner and its original acceptance ticket. It incorrectly refused even a
never-seen request scope. A retained reconciliation receipt is history, not a
process-wide request allowlist. The fence now applies only to a binding whose
state is `retired`. Ordinary scopes still use normal resident identity,
ownership, creation receipts, budget and replay protection.

## Already-approved retired requests

A retired request still cannot create through ordinary acquire. A local
administrator may use `--recover-binding` on the resident server after
independently verifying the exact current canonical request and trusted owner
proposal receipt. The grant names scope, approval, immutable archive, current
epoch and a short expiry. It is never accepted in the public command envelope
or the owner viewer. An approval-shaped string from a caller grants nothing.

The grant atomically records `recovery_ready` and its provenance, without any
native action. Normal acquisition then journals a genuinely new creation in
the current resident session. Reapplying the same grant is a no-op, including
when the new creation outcome is uncertain. Old windows are never selected by
URL/title or closed. All archive bytes, original journals and old action keys
remain intact. Terminal scopes, changed epochs, expired grants, conflicting
receipts and pending input refuse. Terminal delivery for a retired binding
records a fence without claiming the unknown native window was closed.

Status distinguishes a retired binding needing application of an existing
approval from one ready for fresh acquisition. Neither state permits input
replay. `FIREFOX_BINDING_RETIRED` is preserved across endpoint and adapter rather
than being mislabeled as a new uncertain native operation.

## Controller-only managed overlay activation

A full Recreate deployment would unnecessarily replace the healthy browser
process and invalidate current identities. `bin/firefox-controller-refresh`
is an administrator maintenance operation, not a runtime tool or deploy-plan
initialization hook. Run it through Bolt on the supervisor with a source
directory extracted from the exact verified managed Firefox image. It stages
only the complete fixed controller assets in a content-addressed runtime
overlay, not in the profile or installed image paths. It verifies the expected
live controller source, native generation, no pending input and exclusive
endpoint lock before ending only the old HTTP/observer process. Firefox,
geckodriver, KasmVNC and the original profile are not restarted.

The new server obtains the existing exclusive controller lease and reconnects
to the same native session. The administrator command independently reads the
broker's current approval and intact proposal, requires the exact manually
reviewed proposal hash and trusted source, rejects terminal tasks/steering,
and derives scope from the canonical index. It does not infer approval from
proposal wording. Public clients cannot invoke this operation. The bounded
readback verifies the imported controller hash, generation and unchanged
unrelated bindings. There is no automatic refresh retry after a failed readback.

For this incident, the separately inspected exact proposal 24930 authorizes
one fresh catalog coordination binding, not input replay, login, publication or
deployment. Receipt apr-20261022-223843-024159 is trusted Telegram approval for
proposal hash 2b075af5c48f1e62a3173a500f3d6016fc7e93dcfed41b269d39dec197498120.
No second approval for that operation is requested. Fresh request scopes do
not need this retired-binding operation.

## Verification

Before implementation, the new ordinary-scope regression failed with
`old generation preserved in history; no replacement authorized`; the missing
retired-binding path failed independently. Focused tests cover fresh admission,
still-fenced retired bindings, one new binding under a local grant, immutable
history, old-key refusal, grant idempotence, expiry, terminal fencing, failed
commit, uncertain new creation, pending input and independent canonical receipt
checks. The same suites are included in required exact-head CI. Disposable
native and installed original-caller results are recorded separately; unit
fixtures do not claim an active parent request or production acceptance.

The managed `nest::build::firefox` build from source
`4dd0fc9a768b843939f05a3de17855388d01420c` passed its smoke check, published,
and was pulled back as
`registry.gitlab.joyfullee.me/nest/tools/firefox@sha256:524f20afd988a052cb1502161484e12699fb15b93255cde79d71ee28173dbf05`.
Extracted controller, endpoint and both private transport hashes match source.
The image pin is the next ordinary container baseline; controller-only overlay
activation deliberately does not restart the current healthy Firefox pod.

The baked-image disposable scoped canary passed with no owner mounts or external
network. Actual native replies proved unchanged browser/session and owner
binding across controller refresh; fresh scope admission, one new retired-scope
binding, repeated acquire without growth, preserved old unknown native window
and byte-identical archive all passed. Its retired journal is explicit synthetic
fixture setup, not production acceptance. Initial harness attempts exposed
extension first-run settling and competing fixture controller initialization;
the harness now lets the resident server initialize the session before closing
only disposable extension tabs. Those fixture changes are not a production
root-cause claim or a retry of uncertain owner input.

Initial required CI validation/unit jobs failed before tests on GitLab and
registry HTTP 503 responses. Same-head retries were requested; browser fixtures
passed on their first run. Bolt preflight initially lacked ruby_task_helper in
this new worktree. `bolt module install` resolved it; inventory-backed transport
then passed as joy on owl. No direct SSH or ad-hoc Puppet fallback was used.
