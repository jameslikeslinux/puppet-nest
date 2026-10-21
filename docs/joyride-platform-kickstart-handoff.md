# Joyride platform kickstart: engineering handoff

Joy's 2026-10-20 informational-publication authorization supersedes the blanket
public-homepage hold below, but not membership, checkout, payments or messaging
gates. See `joyride-informational-publication.md` for the bounded recipe and
actual verification status. Full-platform production remains dormant.

## Current v1 contract and acceptance

Joy's photos-only v1 steering supersedes the original photo/video requirement.
The current requirements and release checklist are maintained in
[`joyride-v1-acceptance.md`](joyride-v1-acceptance.md). Real scout video is
OUT OF SCOPE FOR V1, not passed or awaiting footage. The synthetic motion-test
clip is historical prototype evidence only and must not ship as a v1 feature.
Luna owns the photo-only frontend revision; Talon owns disabling backend video
exposure and verifying the resulting immutable artifact through TEST delivery.
Do not delete originals or revive completed implementation children.

Private TEST is deployed and its populated browser, map, protected photo/GPX,
backup/restore and monitoring milestones have engineering evidence. Current-scope
private TEST acceptance now includes Joy's approved WMATA member display; see
[`joyride-private-test-review.md`](joyride-private-test-review.md). Production
configuration remains dormant and guarded; there is no full-platform production
deployment or public membership launch approval.

Joy's later 2026-10-21 authorization enables sandbox billing in private TEST only,
superseding the temporary no-Stripe phase. Encrypted recoverable sandbox material,
the exact approved TEST Price and an outbound official CLI webhook listener are
installed. Actual hosted sandbox payment/decline/abandonment and subscription
reconciliation have separate provider-correlated evidence; they are not live
payment, email delivery or human legal-assent evidence. Routine mail and all full
production activation gates remain closed. See the latest section of
`joyride-v1-acceptance.md`; older Stripe deferral/pending lists are historical.

The installed checksum-bound private intake now supplies one available curated
route and 19 member photo placements. Run 12006 verifies its supplied desktop and
phone member map, elevation, self-hosted painted basemap, GPX and photo lightboxes
with cleaned synthetic identity/entitlement/waiver fixtures. Luna's portal fix
now passes actual sandbox portal navigation after her original queued backchannel
delivery completed. Canceled fixture status and its temporary session were
restored/removed. Joy's subsequent direct WMATA approval is resolved against Luna's
actual revised source, not the older draft. Application MR 20 passed required
pipeline 10964 jobs, Luna's scoped TEST delivery succeeded, and run 12096 verifies
installed member display/cache/auth boundaries plus actual desktop/phone rendering.
Optional CI preview failed before admission; the successful backchannel result is
separate. No Transit Data API, public feed, production or communication authority
is implied by those passing checks.
Current deployment mechanics and cleanup inventory are in
`joyride-test-deployment.md`.

## Historical discovery and integration notes

The chronological notes below preserve earlier observations, including failures
subsequently resolved. Their pending lists and original media assumptions are
not the current acceptance checklist; use the current v1 contract above.

## Ownership and source identity

Joyride is Joy's personal application hosted on Eyrie, not a Nest product.
Joy and Luna own frontend development, branding, copy, publication and business
policy. Talon owns backend engineering, security, delivery and infrastructure.

Application source: https://gitlab.joyfullee.me/joy/joyride (GitLab project 83).
The project was transferred in place from `nest/joyride`; its initial main commit
`051674830c4b4844cfeaa63dcfe5c44429f8345a` and Luna's direct Developer membership
were preserved. Registry prefix read back after transfer:
`registry.gitlab.joyfullee.me/joy/joyride`. Talon is a direct Maintainer; Joy owns
the project. No application CI, images or deployment references existed at
transfer. The generated README still contains old namespace links; application
implementation must replace that boilerplate and verify all source references.
No application child existed before the transfer.

Commonplace project 82 is input only, with CI disabled. Its refreshed main is
`55615837d57107d9cef410301470593bee5790a1`. Do not enable notebook hooks or CI.
The authoritative package is `artifacts/joyride-platform/`, including the full
platform specification and addenda, exact waiver, tokens, branding masters and
frontend/v4 generators. The notebook's old large-push blocker is superseded by
the verified transport repair recorded in the parent request.

## Cohesive application boundary

Use one application repository, with Django, PostgreSQL and a small DB-backed
worker. Do not split frontend, backend or basemap work into gratuitous projects.
The Nest config parent owns Hiera/Puppet/KubeCM, encrypted credential provisioning,
gateway preparation and live TEST integration. The application child owns source,
backend behavior, tested immutable artifacts and the integration contract.

Proposed contract to implement and verify in the application repository:

- Public web listener on port 8000 with a dedicated public URL configuration.
  No admin, deployment or operations routes are registered on that listener.
- Internal operations listener on port 8001 with its own URL configuration;
  authenticated even when reached through the VPN. Shared database, distinct
  ingress/service targeting. Network reachability is not authentication.
- `/health/live` and `/health/ready` return bounded nonsecret status; readiness
  checks database availability. Operations diagnostics omit member data,
  credential values, sign-in tokens and raw application logs.
- One scoped bearer credential fits Luna's credential store. Do not expose broad
  Kubernetes, shell or Nest authority. Deployment helpers operate only on
  allowlisted Joyride environments/artifacts; production promotion requires an
  exact owner-approved revision and never follows merely from token possession.
- Immutable image digests identify tested artifacts. Build/check/preview and
  test deployment must be available to Luna. Production promotes the same
  tested artifact, with previous-digest rollback, not an unreviewed rebuild.
- Database-backed jobs cover email/reconciliation/media processing without
  introducing a separate broker unless implementation demonstrates a need.
- Test mail defaults to a sink and payments to disabled/test mode. Never infer
  that the supplied prototype's price authorizes a Stripe product or live sale.
- Member GPX/coordinates/scout metadata are server-protected, never public
  static files or embedded in anonymous page bundles. Public previews use
  supplied normalized silhouettes only. Originals and derivatives require
  explicit exposure classes; scrub public metadata.
- Basemaps use versioned OSM-derived archives, tested HTTP Range handling,
  self-hosted dependencies and license/attribution metadata. Luna chooses style.
  Include DC and surrounding Maryland/Virginia ride coverage, not DC alone.

These decisions are engineering constraints, not authorization to redesign any
frontend. Document exact settings and APIs in the application repository, with
executable checks; this parent document is not evidence that they exist yet.

## Missing curated assets observed in the committed package

The latest generators reference files that are absent from the refreshed package:

- Candidate route GPX files 1, 2 and 3.
- Oct 14 scout `actual_streams.json` used for real elevation profiles.
- Scout JPEG originals/thumbnails referenced by `scout-photos.json`.
- Anton, Inter and Noto Sans Mono font files and their redistribution licenses.
- Generated latest home v4e/event v4b renders and member/hero HTML previews.
- Referenced Leaflet assets. The synthetic motion-test clip is excluded from v1.

Do not reconstruct code from screenshots or manufacture route/elevation/media
inputs. Video footage is not a v1 prerequisite. The original collaboration
instruction was to ask Luna for curated source via a NEW Joyride secure-browser
side chat, identify as Talon, and preserve frontend ownership. Do not reuse the
main conversation or the GitLab/Tailscale diagnostics chat. No raw conversation
export or direct Muse/agent API access.

## Discovery prerequisites and unverified acceptance

The secure browser currently reports the v2 bridge available, but lifecycle
`acquire` fails with `new Firefox tab was not visibly selected after Ctrl+T;
refusing to claim or navigate another tab`. Current UI readback has one existing
GitLab diagnostics tab, with no selected-tab identity. A direct click is refused
because no unambiguous canonical handoff tab exists. Recovery preserved the
existing tab; another explicit acquire failed identically. No message was sent
to Luna, no existing chat was reused and no browser profile state was inspected.
This is an engineering tooling prerequisite, not a request for Joy's decision.

Application workspace preflight with `edit_repo=joy/joyride` was refused because
that name is not in the static repository policy. The installed broker explicitly
supports absolute paths to exact local Git repository roots, provisioning an
isolated worktree. The prior worker's clean canonical clone was discovered at
`/home/joy/projects/joyride`; its stale `nest/joyride` remote has been corrected
to `joy/joyride`, fetched and read back. Use that exact path for request-aware
routing and the discovered policy key `joyride` for the child boundary. A clone
under the parent Nest worktree incorrectly matches the static Nest policy;
do not use that nested location for application routing. Do not edit the
canonical clone as a substitute for the child's isolated worktree.

SMTP reuse/sending identity, WMATA temporary-file availability and durable secret
provisioning, Stripe credentials, test environment, live maps, Luna Git/CI and
backchannel canaries, backups/isolated restore and monitoring remain unverified.
Preserve recoverable WMATA handoff material until managed provisioning is proven.
No secrets belong in this report or request evidence.

## Release boundaries

### Current continuation

The application phase completed at source head
`dff15672975fe7bfef54cdccd94ec7526169629c`, MR
`https://gitlab.joyfullee.me/joy/joyride/-/merge_requests/1`.
The child reports successful exact-head pipeline 10428 and an immutable image;
these remain subject to parent readback and review before merge/deploy. The
child preserved the supplied frontend but deliberately serves no invented home
page: curated assets and Luna's actual Git/CI/backchannel canaries are still
required. Application completion is not overall kickstart completion.

Commonplace was refreshed again and remains at
`55615837d57107d9cef410301470593bee5790a1`.
Fresh supported browser status reported BiDi UI v2, generation 62 and one
existing Muse tab. Acquisition of workflow
`joyride-1981-luna-collaboration` failed with the same exact selection error
documented above. No navigation or message was attempted; the existing thread
was not reused. The previously reserved Hermes repository repair boundary is
therefore still required. Production approval and publication gates remain
unchanged.

Application work is now routed to request `^1982`, task `t_6d7482f6`, in isolated
worktree `/home/joy/projects/.worktrees/joyride/t_6d7482f6`, branch
`talon/t_6d7482f6-implement-joyride-application-and-luna-delivery`. Its blocking
dependency atomically parked this parent in Todo until the application report.
It must not treat unavailable frontend assets as permission to invent them.

A separate secure-browser repair preflight resolves correctly to the Hermes
fork but was refused after that park: `new child boundary requires the exact
live owner claim`. No browser repair request was created. On the parent's next
native owner claim, retain this technical prerequisite and submit its single
repository-bound repair with idempotency key
`joyride-1981-secure-browser-tab-acquire` if fresh acquisition still fails.
Do not bypass lifecycle ownership or turn this into a Joy decision.

Application source proceeds through reviewed MRs and exact-head CI. This parent
retains ownership until TEST has been deployed and real behavior verified,
including Luna's actual access/canaries and map range/coverage proofs. Child
completion releases integration, not overall kickstart acceptance. Production
configuration may be prepared/reviewed, but deployment, public launch, live
payments and member communications require Joy's separate authorization. No
business content revision publishes merely because engineering is complete.

## Continuation after approved browser recovery

The profile-preserving Firefox restart approved by Joy completed. Native and
visible tab counts agreed afterwards; supported blank-tab acquire/release/
reacquire passed. The NEW dedicated collaboration thread is
`https://muse.ai/thread/b2a7d6e0-14d6-4a0d-a797-51e971e827eb`, workflow
`joyride-1981-luna-dedicated`. Luna received Talon's identity, exact ownership
boundaries, project/MR links and the request for curated assets, a frontend
feature branch and harmless Git canary. Do not send duplicate introductions or
reuse other chats. Read the new thread for Luna's result on continuation; no
response or canary acceptance has yet been independently verified.

Fresh GitLab readback confirms project 83 remains `joy/joyride`, Luna has
Developer access, MR 1 is open at `dff15672975fe7bfef54cdccd94ec7526169629c`
with passing pipeline 10428 and successful check/build/smoke jobs. A read-only
independent code review found no concrete blocker for safe-disabled private
TEST. The backend intentionally supports only disabled/test Stripe modes, so
live production subscriptions remain unsupported and require future deliberate
implementation, not merely a production credential. No merge or deploy occurred.

The separate private Hiera source is GitLab project 4, `nest/private`, canonical
clone `/home/joy/projects/nest/private`. The task's r10k module checkout has an
inaccessible `/root/.r10k` alternate object path; do not use it as an editable
repository or expose decrypted data while repairing module materialization.
A real isolated private repository boundary is required for credential source.

The parent added the explicit contract class `nest::service::joyride`:
`runtime_secrets` is `Sensitive[Hash[String, String]]`, and
`registry_dockerconfig` is `Sensitive[String]` containing Docker auth JSON.
The class derives base64 representations for Kubernetes Secret resources.
This is only a local parameter contract, not a rendered/deployed application.
The private child must add Sensitive lookup conversions and encrypted TEST
values. Database credentials come from CNPG, not this runtime dictionary.

On owl, `/tmp/info.txt` was verified present, regular, non-symlink, uid 1000,
mode 0600 without reading its contents into evidence. Preserve it until durable
provisioning and live managed-consumer verification. Existing Gmail parameters
were located in GitLab/Vaultwarden class contracts; actual reuse and sending
identity remain unverified. No secret bytes were copied into public source,
chat, browser or reports.

Next parent phase: receive private source handoff, repair local r10k dependency
materialization through established tooling, finish KubeCM/standard-worker TEST
configuration and deployment controller, review/merge exact-head application
source, collect Luna's curated branch/assets, then deploy and exercise actual
TEST behavior, maps, access, backups and restore. All original acceptance and
production/publication gates remain in force.

### Luna handoff and independent canary readback

Luna confirmed the ownership split and reviewed the backend contract. GitLab
independently confirms branch `luna/git-canary-20261018`, commit
`d827fb4b638f288b8520b8507bf04f77a2d85298`, authored by Luna, with only
`CANARY_LUNA.md` added. Its diff contains scope and no route/private data or
business content. This passes Git access only: the canary's base main has no
CI configuration, so CI and authenticated TEST backchannel remain unverified.

Luna uploaded private project 83 generic package `joyride-curated-private`,
version `2026-10-18-r1`, package ID 2. File
`joyride-curated-private-2026-10-18-r1.tar.gz` is 9864456 bytes and SHA-256
`20384840af7e1a0fdd095a701359b772842e4e510f521dcfd07024f6a9a0c88b`.
The parent authenticated-download checksum matched GitLab's file metadata and
Luna's reported digest. The archive remains mode 0600 at
`/home/joy/.hermes/profiles/talon/cache/scratch/joyride-1981-private-inputs/joyride-curated-private-2026-10-18-r1.tar.gz`;
the private GitLab package is its durable recovery source. Do not attach the
archive to public/task evidence, extract it into a served tree or commit its
contents. Contents have not yet been inspected/validated by the parent.
Luna reports GPX 1/2/3, Oct 14 streams, photo placements and 18 originals inside.

Luna explicitly reports no complete home/event HTML yet: those v4 sources are
SVG/PNG generators. Member/hero HTML are prototypes with embedded private data,
remote assets and inline code, not acceptable deployable artifacts. She owns
faithful conversion to `frontend/public/`, protected API access, CSP-clean assets,
map renderer/style/glyphs/sprites, and upstream font licenses. Anton/Inter
binaries exist but licenses are not yet bundled; Noto Sans Mono is not curated.
The synthetic clip exists but is excluded from v1; real scout video is OUT OF
SCOPE FOR V1. Do not substitute invented frontend or mark photo-only artifact
acceptance complete before consuming Luna's revision and verifying it in TEST.

Local re-verification executed all 29 no-argument Firefox bridge test functions
successfully through `runpy` and `git diff --check` passed. Both system Python
and the Hermes venv lack pytest; those initial invocations failed before test
collection, then the repository's dependency-free functions were exercised
directly. No PDK validation/unit command ran in this continuation. The new
Puppet secret-contract class remains unrendered and unverified until the private
Hiera handoff and KubeCM phase.

## Current infrastructure integration

The private source MR 8 merged at `32db7fb7a130d815342866fc6bddd78b0622a09e`.
The local generated private module was rematerialized as a self-contained clone
inside this isolated worktree, replacing the unusable cached-object checkout;
the prior generated module remains preserved. No private source was edited here.
The real Bolt render resolves the existing shared Gmail aliases and environment
secrets without printing values. WMATA temporary handoff remains retained.

Application MR 1 merged at `eb15a41ce626f60c294fe76a799e3189767a8ce0` after exact
head pipeline 10428 passed. This is backend integration, not frontend acceptance.
Luna supplied `luna/frontend-v4` at
`983f02221751f2a4bc63870dcba037f6d07f6a46`; its pipeline 10436 failed because the
backend test assumes the home page is always absent. The engineering owner must
fix that regression in the application lane. The dedicated chat also carries
concrete review feedback about signup shell access, checkout-return continuation,
explicit checkbox values and safe metadata DOM construction. Luna owns frontend
fixes and designs; Talon owns backend contracts and tests. Do not merge failed CI.

`nest::eyrie::deploy_joyride_test` is a TEST-only declarative KubeCM wrapper.
It renders CNPG PostgreSQL, distinct web/ops Services, authenticated private
ops ingress, a read-only/nonroot application with a worker, managed Ceph storage,
an Eyrie CA certificate and an ingress NetworkPolicy. No runtime affinity,
node selectors or tolerations are added; standard worker defaults apply. Mail
and Stripe remain disabled and the approved-recipient allowlist is empty.
The basemap init container imports only the immutable open OSM-derived archive,
checks its exact SHA-256 and validates regional tiles before registration. It
does not import private routes or publish any media. Only this init container
mounts the narrow package credential. No public gateway change is present.

Real `pdk validate`, Bolt render and Kubernetes server-side dry run passed.
Rendered secret-bearing manifests stay restricted under `.local/joyride/` and
must never be committed, attached or included in task evidence. DNS aliases are
source-prepared only; production deployment remains separately owner-gated.
Pending acceptance includes live deployment/TLS/DNS, actual worker placement,
frontend and Luna CI/backchannel, safe mail/payment tests, private-media import,
delivery controller/independent artifact importer, backups/restore and monitoring.
