# Shared Firefox input verification and tab provenance repair

## Scope and limits

Agent Request ^2016, task t_d8b2ce42, independently repairs shared Firefox
platform seams reported by the original Joyride client ^1981. It does not pause
that client's application work. The original sanitized report remains at
`/home/joy/projects/.worktrees/nest-config/t_befb85e8/build/joyride-run11865/browser-defect-report.md`.
Its action keys, uncertainty and distinctions remain authoritative.

The report proves seven total tabs, not seven Muse tabs. Joy separately saw
approximately five Muse tabs. Thirteen expired workflows were records, not proof
of thirteen extant tabs. Fresh supported authenticated, TLS-verified
`browser.eyrie` status and accessibility snapshot during this repair expose one
New Tab, an empty URL and generation
`a71c8869a8fb38d9e6ba5ad1d12dd93f26f27c9fa1db9a350042713ef05be217`.
They retain uncertain old workflows. This contradicts the earlier topology but
does not establish who changed it, whether the old tabs were safely disposed,
or whether a canonical Luna chat is usable. No old tab was closed, recovered,
rebound or navigated by this repair worker. No private draft or chat content was
copied, and no uncertain typing or Send action was replayed.

The original DOM/accessibility/screenshot disagreement has not been reproduced
as a rendering failure here, and no compositor or page root cause is claimed.
Historical session exhaustion is not claimed to be a fresh live incident.
The demonstrated reporting and lifecycle defects below are narrower.

## Demonstrated source defects and repair

The initial focused regression run failed five cases: ordinary and selector
input both reported delivered without visible-field evidence; ordinary readback
failure still left a successful journal; a dropped Ctrl+W forgot ownership and
reported successful closure; and recovery discarded binding provenance.

- Typing now reserves its existing action key before input and commits delivery
  only after readback. Exact, bounded, private AT-SPI text/caret observations
  establish ordinary insertion on the same focused field and tab. Locator and
  coordinate confirmations must refer to that field. Selector input additionally
  requires expected native value, focused AX value and native active-element
  identity to agree. Raw comparison values are neither journaled nor returned.
- Missing, ambiguous, redacted, oversized, selected-text or otherwise unsupported
  observations remain `delivery_uncertain`; replay never sends input again.
  `typed_chars` is not claimed for unconfirmed input. Rich-text controls without
  exact value/selection observations can be dispatched but remain uncertain;
  their old dispatch-only tests no longer call that delivered. Readback failure
  leaves the reserved `delivery_started` journal, which also blocks replay.
  AX confirmation is not pixel OCR or proof of page submission/completion.
  New journals retain only a confirmation boolean. Historical dispatch-only
  typing journals without that evidence remain untouched and non-replayable,
  but are not reported as verified delivery or used to clear recovery uncertainty.
- Native selector mapping previously activated every handle to scan URLs and
  rejected duplicates. It now observes the selected context through the same
  WebDriver session's BiDi connection, using the existing active-window and
  isolated-document-visibility checks. BiDi context IDs and WebDriver handles
  share the W3C navigable identity. Mapping is revalidated before input. No
  caller-supplied script, URL/title ownership inference or second session.new
  is introduced. Borrowed connections close without ending the owner's session;
  the WebDriver context retains its existing bounded teardown.
- Explicit recovery can renew exact same-process canonical identity when the
  binding is certain, or its only recorded uncertainty is lease expiry, and no
  action is uncertain. It neither selects a tab nor discards a draft. Unknown
  historical uncertainty, generation changes, missing identity and uncertain
  closure cannot use this path. Other recovery preserves an abandoned-binding
  record and all journals. Known abandoned tabs remain claimed; unresolved
  provenance prevents repeated replacement-tab creation. No uncertain input is
  reclassified as successful by recovery.
- Release persists closure uncertainty before its one shortcut, then observes
  the exact expected survivor identity set and count within a bounded window.
  A dropped/ambiguous closure retains ownership and blocks another shortcut.
  Status exposes bounded provenance facts without page or draft content.

## Focused verification and image evidence

Source implementation commit:
`33446a97108d6ec4d9b71bad32999d6f5122da70` (including the historic-journal
confirmation fence after initial implementation `d4680c858fd15e22837613fd7705de930fe8709b`).

The nine focused Python suites passed 113 tests. The new stdlib-only regression
script passed all eleven tests directly and is in Secure browser fixtures CI.
`git diff --check` passed. Required exact-head CI is recorded on the MR; these
local results are not a substitute for that gate.

The enhanced isolated regression on the unchanged installed-image content
failed with the exact native selector mapping refusal, explicitly no input sent.
Two duplicate-input overlay cycles then passed. A later expanded harness attempt
failed a fixture title-readiness assertion before reaching recovery checks; that
run is retained as failed, not counted as a pass. The harness now bounds
read-only title observation rather than replaying navigation or input.

The final managed Bolt build refreshed the existing production-family image in
an isolated build container, applied the checked-out Puppet source and passed
its headless smoke test. Dedicated published tag:
`registry.gitlab.joyfullee.me/nest/tools/firefox:ar2016-input-33446a97`.
Independently pulled registry digest:
`sha256:3c295158d93aa2450e63a76eaa9be9675c16238d4a61c422b946d71e976600c1`.
Local image config identity:
`sha256:ad89463a77b1ac62993630ace9f1473e700a5d34106387aef1077f7dfde788d3`.

The final pristine image, without overlays or an owner profile, passed two
cycles and 67 public operations in 114.667 seconds, maximum operation 6.567
seconds. It verified equal-title/equal-URL native input, exact textarea
entry/replacement, protected-field redaction, idempotent replay, four explicit
recover/acquire pairs with no added replacement tabs, exact survivor count after
release, source pagination, endpoint reconnect/outage and bridge refresh.
Five survivor identities and browser generation were preserved. The disposable
browser exited gracefully and its container was absent afterward. This was a
TLS-verified localhost fixture through the shipped public adapter, with client
subprocess execution forbidden and no kubeconfig. It is not `browser.eyrie`
production acceptance, a live Luna chat test or a longevity certification.

A separate stronger coordinate-status run initially refused its fixture title
assertion because the empty profile's Bitwarden onboarding tab became selected.
It did not reach coordinate input. The returned query identified that actual
selected page rather than guessing the fixture. A bounded, opt-in initial
onboarding observation now precedes fixture workflows. On the identical final
image, the strengthened run passed 52 operations in 92.47 seconds, including
an explicit `delivered` and `visible_value_confirmed` assertion for coordinate
multiline input, with five survivor identities unchanged. This is a fixture
startup race, not proof of the original Muse rendering cause. No production
extension or profile configuration was altered. Receipt:
`coordinate-confirmation-ready-green.json`; the failed run remains retained.

Source and final-image hashes independently matched:

| Component | SHA256 |
| --- | --- |
| UI bridge | `b9ce86f8095c795df931953b62c530fc0996396332748b1a31bb4ec4cdb0038b` |
| HTTP endpoint | `cf7d733550e0438c98bd48070bef323e674e151a22a155d627ea71357be33d11` |
| Bounded BiDi reads | `75360acb63bf8af19fd52f6bcbf0cb2c11cbabd3b803610d3e3e1f6ff0d5ae70` |
| Local BiDi session helper | `b058f32129206a2c2af126973a1421dfc92eb38b99703763a061b16326c19559` |

Safe receipts live under this task's `build/browser-repair/`: original
`isolated-red.log`, passing `isolated-green.json`, `pristine-green.json` and
`final-pristine-green.json` and `journal-pristine-green.json`. The journal-fenced
receipt is the authoritative final pristine
revision. Raw build/fact logs are not user deliverables.

Registry push succeeded through the existing managed credential path. The
initial locally recorded manifest digest was not remotely pullable; a tag
readback identified the registry's compressed manifest and an exact digest pull
then succeeded. The local digest was not used as deployment evidence. A local
registry commit attempt had first failed because inherited registry credentials
caused a login to localhost, where no registry exists. Publishing used the normal
managed remote-registry plan, not a manual credential workaround.

## Bolt preflight and deployment boundary

All commands ran from
`/home/joy/projects/.worktrees/nest-config/t_d8b2ce42`, using this worktree's
`bolt-project.yaml`, `inventory.yaml` and local module resolution.

Initial `bolt inventory show owl --detail --format json` failed with:
`Could not find module ruby_task_helper containing task file task_helper.rb`.
`bolt module install` populated the missing worktree dependencies. Repeating
inventory discovery succeeded, and
`bolt command run 'id -un && hostname -f' --targets owl --stream` returned `joy`
and `owl`. No direct SSH or ad-hoc Puppet fallback was used.

The source build used the repository Bolt wrapper and existing build plan:

    sudo -n env BOLT_CLEANUP_CMD='podman stop nest-firefox-ar2016-input >/dev/null 2>&1' ./bin/bolt-wrapper plan run nest::build::firefox container=nest-firefox-ar2016-input cpu=zen5 tag=ar2016-input-33446a97 registry=registry.gitlab.joyfullee.me build=true init=false deploy=true --stream

The initial build-container initialization used `refresh=true`,
`tag=ar1993-selected-context`, `deploy=false` on this same dedicated container.
Build publication does not activate the shared browser.

Fresh read-only deployment metadata still reports generation and observed
generation 42 and the old digest
`sha256:2fe926ca946ff51879cbc089eea9615b4c3ef21e2a72aca157c8a5ac539728ce`.
No production rollout has occurred. The KubeCM deployment uses Recreate;
activating the pinned repair interrupts the shared Firefox session and changes
process/object identity. It requires a new exact authorization, not reuse of
^1993/^2010 or any consumed restart/binding approval.

## Original-client installed retest handoff — still outstanding

After exact-head CI, normal source merge and separately authorized managed
activation via `nest::puppet::deploy`, the existing owl tagged bridge apply as
needed, and `nest::eyrie::ai::deploy_firefox`:

1. Read back deployed digest, generation, endpoint/bridge hashes and source
   parity through supported controls. Record pod/PVC continuity separately from
   browser identity. Installing files is not proof an active client reloaded
   tool descriptions; do not forcibly reclaim the original Joyride worker.
2. The ORIGINAL ^1981 client must refresh status/snapshot in its own runtime and
   independently verify a usable intended canonical Luna chat. The currently
   exposed New Tab is not evidence of that chat. Never adopt a same-URL/title
   tab, recover an uncertain old binding, or create another Luna tab by guess.
   Obtain exact binding/session authority first where needed.
3. Inventory actual tabs and retained/abandoned provenance. Only close positively
   identified obsolete automation tabs when their draft and action disposition
   is known. Preserve owner/unproven tabs. Missing old-generation object IDs do
   not prove old tabs were closed. Record that bounded uncertainty rather than
   inventing a clean backlog.
4. Verify ordinary entry and explicit replacement using authorized nonsecret
   draft intent, independent visible/readback parity, duplicate-URL identity
   safety and no unintended tab growth. Do not send a chat, publish a message or
   replay uncertain input to make the test pass. No new key for an old action.
5. Preserve `joyride-1981-no-stripe-luna-run11812-draft` and
   `joyride-1981-no-stripe-luna-run11812-send` journals. The latest run 11860 keys
   were absent from its sanitized checkpoint and were not guessed or recovered
   through unsupported filesystem/profile inspection in this run. Preserve all
   existing journals in place. A successful historical fallback is not current
   publication delivery.
6. Return the original-client result to ^2016. Isolated new-tab success alone
   cannot release this repair's acceptance gate. Joyride application deployment
   and CI-isolation work remain independent throughout.
