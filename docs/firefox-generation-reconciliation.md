# Explicit Firefox generation reconciliation

Status: candidate source, not activated. Request ^2085 / task t_274a959c.

Joy approved scoped generation reconciliation through
apr-20261022-202336-6f806a. That approval retains a fresh no-unresolved-input
safety gate. It does not authorize silently clearing historical uncertain input.

The resident server accepts a local administrator JSON grant through
--reconcile-generation or FIREFOX_GENERATION_RECONCILIATION_GRANT. Neither the
public authenticated API nor the owner viewer accepts this operation. The
exclusive controller lease must already be held. Grant fields are approval,
scope and journal_sha256; scope must be the single authorized request, not owner.
The approval receipt is an audit reference, not an authorization mechanism:
the administering operator must verify the actual owner approval separately.

The journal hash is SHA256 of a sorted JSON object mapping every top-level
state-directory *.json filename to its byte SHA256. Every such journal is
archived byte-for-byte in a read-only, content-addressed generation-history
bundle. The bundle is fsynced before the replacement controller journal is
committed. Existing history must match; conflicts refuse rather than overwrite.

Every native and legacy action must be delivered. Started, pending, uncertain
or unrecognized states refuse before any native operation or archive write.
The native driver must report ready; an occupied session is not terminated.
Reconciliation is permitted only for an unconnected, lost generation. It never
closes or navigates any existing window. Old request bindings are retired, not
reported closed. Old viewer capabilities no longer appear in the live registry.
Only the owner and the explicitly named acceptance request can acquire fresh
bindings. Other requests remain refused without replacement. Action keys stay
non-replayable and complete prior bindings remain in immutable history.

Fresh owner binding uses existing native active-window identity and selected
context observation, never URL/title matching. Ambiguous active-window identity
stops acquisition. Native session creation still uses the existing single-shot
reservation. Repeated same-grant reconciliation is a no-op, including after a
crash between the grant commit and native connection. It cannot retire the new
generation a second time. Another generation loss requires a new decision and
implementation, not reuse of the old grant.

## Newly discovered production safety failure

Read-only Kubernetes inspection on this continuation found that windows.json
has 87 delivered actions and no unresolved input. Inspecting the complete
legacy journal as required by reconciliation found two unresolved action keys
in state.json:

- SHA256 50ed8a0d8dee98114c31b8e093741d439e43312631d9cf550e76d10378042e72:
  type, delivery_uncertain, created_at 1792547530.7006593,
  workflow joyride-1981-informational-publication.
- SHA256 4917185f6cfbbbc3ec1bc66e86795e85c4d1ddb3b1d4295760f11bc34acb9085:
  click, delivery_started, created_at 1792438259.0176575,
  workflow milkv-3707-lts-followup.

No text, selector, page content, cookie, login or credential was inspected.
These are older retained legacy records, not proof of current input delivery.
They cannot be reclassified as delivered and cannot safely be replayed. The
legacy journal has 448 delivered actions in addition to those two records.
Two other retained controller snapshots each contain 64 delivered records.
The exact all-journal safety digest at the observation was
b32e00bb495b4f9c0529a3eaee53f3acf4c95bcf3810903f82184653f8868a7d.
It must be recomputed immediately before any future operation.

The candidate correctly refuses this production state. No production journal,
profile, binding, browser session or window was changed. No new image was
activated. The existing approval's no-unresolved-input gate cannot be satisfied
by ignoring legacy delivery_state fields. A new exact owner decision is needed
before adding any narrowly grandfathered historical-action retirement path.
Such a path must preserve the original states and bytes, exempt only the exact
reviewed action records, refuse any additional unresolved input, and never send
or acknowledge those actions as delivered. The current source intentionally
contains no exemption switch.

Working installed request-context acceptance remains incomplete. The prior
installed creation-receipt repair and finite broker routing remain deployed.
The separate production r10k firewalld authentication failure recorded in
.local/firefox-installed-recovery-acceptance.md remains unrelated to HTTPS
browser transport and is not permission for a direct SSH/Puppet fallback.
