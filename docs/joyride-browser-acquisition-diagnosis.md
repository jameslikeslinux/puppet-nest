# Joyride browser acquisition diagnosis

Task: `t_befb85e8`, Agent Request `^1981`.

## Verified findings

The shared Firefox session cannot currently provide consistent visible-tab
identity. Supported status and accessibility snapshot report browser generation
62, one chrome tab and no selected tab. The X11 screenshot still shows the
existing Luna diagnostics conversation. The browser's native WebDriver reports
eleven handles and an active `about:newtab` context. No handles were switched,
closed or navigated during the native diagnostic; only handle enumeration,
active-handle and active-URL reads were used. These readings cannot be treated
as interchangeable evidence of the owner-visible tab.

One supported acquisition attempt in this run, with workflow
`joyride-1981-tab-repair-proof`, returned:

    new Firefox tab was not visibly selected after Ctrl+T; refusing to claim or navigate another tab

The eleven native handles were observed after that attempt. There was no native
baseline immediately before it, so this run does not establish which earlier
attempt created each blank tab. The result demonstrates that failed visible
readback is not evidence that no tabs exist or that retrying Ctrl+T is safe.
Further creation attempts stopped. No existing conversation was navigated,
closed, reused for collaboration or sent a message.

A read-only AT-SPI chrome probe confirmed the sole reported chrome tab has no
SELECTED state, even after clearing its accessibility cache. Its tab-list
Selection interface reports zero selected children. There is one Firefox
accessibility application, PID 62, matching the browser generation; this was
not a simple selection of a different Firefox application registration.

The visible Navigator window is unique. Xmonad is running, but does not advertise
`_NET_ACTIVE_WINDOW`; the bridge already falls back to `windowfocus`. X11 focus
readback identifies the expected window. A reversible one-pixel window resize
and restoration did not restore consistent readback. The underlying reason for
the chrome/native divergence remains unproven. No restart or profile change
was attempted. Do not mislabel this as a verified asynchronous-publication race.

## Local protective implementation

Changed `files/firefox-browser/firefox-ui-bridge.py`:

- Acquisition refuses before input when a unique selected tab is absent.
- Before Ctrl+T delivery, the locked workflow state durably records uncertain
  creation intent. Failed input/readback leaves that binding uncertain, so the
  same workflow cannot create another tab on retry.
- Successful acquisition replaces the pending record with the existing normal
  ownership record. No cleanup, journal reset, profile access or ownership
  fallback was added.

Regression coverage in `spec/app/hermes/test_firefox_ui_bridge.py` exercises
missing/ambiguous selection, failed readback and retry refusal, and durable
intent before interrupted delivery. These are protective changes, not a claim
that the live browser session is repaired. They remain local, uncommitted,
unpublished and undeployed pending normal source review and exact-head CI.

Verification:

- Firefox bridge function tests: 29 passed.
- Secure-browser adapter function tests: 11 passed with the CI-declared
  `SECURE_BROWSER_CONTROL_MODE=firefox-ui-v1` fixture environment.
- Browser tab ancestry suite: 9 tests passed.
- `git diff --check` passed.
- An initial adapter run inherited the live v2 mode and failed importing the
  fixture's absent `tools.secure_browser_bidi`; rerunning with its CI-declared
  v1 fixture environment passed. No source change was made to hide that error.
- Local PDK validation and unit commands were not run.

## Platform prerequisite readbacks

Commonplace refreshed main remains
`55615837d57107d9cef410301470593bee5790a1`; no notebook CI, hooks or dispatch
were enabled, and no notebook source was changed.

Application MR `https://gitlab.joyfullee.me/joy/joyride/-/merge_requests/1`
was independently read back: open, source head
`dff15672975fe7bfef54cdccd94ec7526169629c`, passing exact-head pipeline 10428,
source and destination both in project 83 under `joy/joyride`. It is not merged
or deployed. The application README explicitly says the preserved frontend
bundle is not deployable and `/` returns HTTP 503 until Luna's complete frontend
is integrated. That is not a working TEST deployment.

Bolt initially failed from the task worktree because the project lacked its
`ruby_task_helper` module:

    Could not find module ruby_task_helper containing task file task_helper.rb

`bolt module install` completed successfully. From the same worktree, both
`bolt inventory show owl --detail --format json` and
`bolt command run 'id -un && hostname -f' --targets owl --stream` then succeeded.
The inventory resolves owl through SSH as joy, and the smoke returned `joy`
and `owl`. This is not a transport blocker. No direct SSH or ad-hoc host Puppet
deployment was used.

## Recovery boundary and remaining acceptance

A controlled shared Firefox process restart may reconcile its native and visible
state, but could lose unsaved UI state or require owner login recovery. It is
not a verified fix, and preserving the profile PVC is not proof that every open
tab or unsaved draft will restore. Obtain an explicit decision on that tradeoff
before restarting the browser. Preserve all current workflow/action journals;
do not delete the PVC, profile, authentication state or unidentified tabs.

After recovery, verify native/visible tab consistency before any further input,
then exercise supported blank-tab acquisition/readback/release. Only then open
the authorized new dedicated Joyride side chat. Do not reuse the existing
conversation. If recovery does not restore consistent identity, stop input and
continue engineering diagnosis instead of weakening ownership checks.

The overall kickstart remains incomplete: curated frontend/assets, Luna's real
Git/CI/backchannel canaries, infrastructure configuration, managed credentials,
working TEST deployment, served map proof, backups/isolated restore and app
monitoring still require implementation or verification. Production deployment,
public launch, live payments and member communications remain separately gated.

## Approved recovery execution

Joy approved proposal comment 22664 through approval
`apr-20261018-222111-dd2c6e`. The scoped recovery was performed without deleting
the profile, PVC or workflow/action journals. On `firefox-774b758c59-mb4l6`, the
exact affected Firefox PID 62 received SIGTERM. Its launcher exited and Kubernetes
restarted the container, retaining the `firefox-profile` PVC at
`/home/kasm-user`. The first immediate readiness wait raced container shutdown;
the subsequent deployment rollout and container readback confirmed restart count
2 and a running, ready container. No app or host configuration was deployed.

After recovery, accessibility reported one selected New Tab and native read-only
WebDriver enumeration reported one handle with active URL `about:blank`.
Supported lifecycle acquire, release (preserving the tab), and reacquire all
succeeded for workflow `joyride-1981-luna-dedicated`. The browser generation field
remained 62 because the restarted container reused PID 62; generation alone is
not proof that a container/browser did not restart.

The newly acquired blank tab was navigated to Muse. The existing account session
was retained. The explicit New side chat control opened `/thread/new`; only that
new chat was messaged. The persisted dedicated thread is
`https://muse.ai/thread/b2a7d6e0-14d6-4a0d-a797-51e971e827eb`, titled
`Joyride - Luna and Talon platform delivery`. Browser text readback confirmed the
scope/assets/Git-canary request was sent; a visible screenshot showed Luna working
on it. No frontend handoff, Git canary or CI/backchannel canary is claimed yet.
No existing main/diagnostics conversation was messaged. No raw browser captures
or conversations are attached to the task evidence.

The local protective acquisition changes remain uncommitted and undeployed.
Recovery established a working current session, not durable protection against
all future stale accessibility state. Continue normal source/CI delivery for
the guard before describing it as deployed.
