# Joyride v1: current requirements and acceptance

Canonical program: Agent Request ^1981, task `t_befb85e8`.
This is the current Nest integration requirements/checklist, not launch approval.
Joy's photos-only steering recorded on 2026-10-19 supersedes the original
photo/video deliverable and every earlier real-scout-video pending item. The
original request and chronological reports remain historical evidence, not a
reason to require footage. Commonplace is input-only; do not alter its CI/hooks.

Joy's 2026-10-20 no-Stripe steering also supersedes the original current-phase
provider acceptance requirement. LLC/account setup, credentials and REAL Stripe
sandbox acceptance are DEFERRED, not passed and not blockers to this phase.
Do not repeat the withdrawn Stripe setup proposal or schedule automatic enablement.

## Ownership and unchanged requirements

Joy and Luna own business decisions, legal/content approval, branding and ALL
frontend development. Talon owns backend/platform engineering, security,
infrastructure, CI/delivery and reliability. Preserve supplied assets and source;
do not invent copy, prices, guest eligibility, waiver policy, styling or imagery.
The application remains `joy/joyride`; Nest deployment is `nest/config`.

V1 media is PHOTOS ONLY. Keep curated GPX/elevation, route/scout photo metadata,
photo derivatives, metadata scrubbing, controlled public/member exposure,
server-side authorization and backup/isolated restore in scope. Private route
coordinates and scout metadata must not leak through public silhouettes or
static bundles. Do not delete original media or undertake broad backend removal.
Dormant reusable video internals may remain harmlessly, but no video ingest,
transcode, poster or playback capability may be exposed or counted as shipped v1.
No future-video task or footage request is needed for this version.

Other current requirements remain: verified email-only sessions, explicit disabled
billing with the real Stripe adapter preserved for later activation, versioned verbatim
approved waiver with resume/fallback, protected member routes/GPX, self-hosted
regional OSM basemap and dependencies with attribution, Luna's independent Git/
CI/TEST delivery, immutable-artifact promotion/rollback, environment separation,
private authenticated operations, managed secrets, backups and monitoring.
WMATA follows Joy's later explicit correction: incorporate data in the own
application, never republish Transit Data through our own API. Luna has its own
WMATA connection. Share bounded cache-state metadata receipts, not incident feeds.

## Acceptance ledger

A prior milestone is not proof of the next artifact. Keep historical evidence,
then verify changed behavior against the exact resulting TEST artifact.

| Item | Current disposition | Evidence / next gate |
| --- | --- | --- |
| Real scout video | OUT OF SCOPE FOR V1 | Closed by Joy's scope reduction, not tested/passed; no footage request. |
| Synthetic motion-test MP4 | Prototype evidence only | Run 11773 exercised playback then removed fixtures; clip must not ship as v1. Do not rerun video acceptance. |
| Photos-only frontend | Verified on private TEST, Luna-authored | Application MR 6, exact source `028a8df0994dd9ad33659c3473d5982316dd4c58`; run 11808 verifies all release hashes, absent MP4/video UI, photo hero and populated member photo lightbox on desktop/phone. No Talon frontend edits. |
| Backend photo-only exposure | Verified on TEST with Luna's photos-only frontend | Application MR 5, exact source `ff6385dc43e6e99aab30880f2975842952f52bad`; runs 11783 and 11808 verify installed source parity, ready-video omission/direct denial, pre-transcode processing rejection, blocked historical static clip and unchanged protected photos/ranges. Dormant schema/originals remain. |
| TEST website, sessions and protected route/photo/GPX | Prior milestone verified | Run 11770 ingress/session checks and run 11773 populated desktop/phone checks; repeat affected photo/security behavior on resulting photo-only artifact, with exact fixture cleanup. |
| Regional self-hosted basemap | Prior milestone verified | Existing checksum/region/range evidence and run 11773 painted tiles/HTTP 206; preserve self-hosted attribution/dependencies and private-route separation. |
| Luna Git/CI/backchannel | Prior milestone verified | Run 11733 actual independent Tailscale status/diagnostics/deploy success; preserve narrow trust and credentials. No new access request for closed canaries. |
| Managed SMTP identity/receipt | Approved bounded test verified | Preserve previous sender/receipt evidence; routine mail and member communications remain disabled/gated. |
| WMATA worker/cache/recovery | Prior milestone verified | Runs 11759 and 11768 managed upstream and disposable failure/backoff/recovery; metadata-only receipts. |
| WMATA member display | OPEN, draft preserved and inactive | Luna's draft at `3fc625ebdf080eca453f4f566834d9c3f3d20661` passed synthetic rendering/escaping checks. MR 6 deliberately omits its marker, fragment and CSS; no unapproved wording is served. Luna owns markup and Joy/Luna retain editorial/terms approval. No Transit Data JSON/API, raw feed export or incident-bearing handoff. |
| Disabled/no-op billing | Backend/worker and Luna frontend verified on private TEST | Application MR 7/run 11814 preserve the disabled API/worker protections. Application MR 8/run 11835 verify Luna's graceful UI on desktop/phone, zero billing POSTs and installed auth/CSRF/waiver/private-access boundaries. Factual wording remains Luna-drafted, not publication approval. |
| Real Stripe sandbox/provider acceptance | DEFERRED by Joy | LLC/account setup, selected account/product/Price ID, secure credentials and actual checkout/portal/signed-webhook/reconciliation proof belong to later explicit activation. Not passed and not a blocker to the no-Stripe phase. No live payments. |
| Backup/isolated restore and monitoring | TEST milestone and transport repair verified | Runs 11767/11768 protection and alerts; run 11808 populated photo restore; run 11809 repaired managed capture, completion readback and exact-generation isolated restore with independent cleanup/live continuity. That managed generation was empty of members, not a populated photo drill. |
| Production source preparation | PARTIAL, dormant | Separate zero-replica DB/PVC/listener candidate, serial migration, pinned basemap initialization, suspended monitor/backup and dedicated VPN TLS ops candidate with real pinned-nginx fixtures. Compile guard remains TEST-only; managed production secrets, private ops live acceptance, gateway, promotion and real production protection acceptance remain open. See environment boundaries. |
| Production deployment/public launch/content publication | NOT AUTHORIZED | Separate Joy approval of relevant revision required; no inferred authority from scope reduction. |

## Concrete source-facing work

1. Luna removes video from hero slideshow/member prototypes and delivers a
   revision through the existing dedicated Joyride collaboration path. Consume
   that revision faithfully through the existing integration/release path before
   declaring a v1 artifact photo-only. Do not substitute a Talon frontend rewrite.
2. Application MR 5 closes backend listing, direct member/public file/poster,
   processing and known static-video exposure. Run 11783 deployed its verified
   immutable artifact through the normal importer/controller and verified source
   parity. Keep those gates closed; do not erase originals or rebuild a video
   pipeline. The retained clip and enabled frontend references still require
   Luna's revision, not merely a blocked URL.
3. Preserve photo processing, authorization, sanitized metadata and HTTP range
   behavior. Deny video by type before reading/transcoding files, omit it from
   lists, deny direct URLs/posters, and ensure the shipped static artifact has no
   accessible MP4 or enabled video UI. An empty live media table alone does not
   prove fail-closed behavior. Keep historical prototype fixtures clearly marked;
   new v1 acceptance must be photo-only with negative video cases only.
4. Consume Luna's actual markup using the delivered escaped server-rendered WMATA
   seam, without inventing display copy/design or introducing a Transit Data
   endpoint. Rendering and terms/editorial approval remain explicit gates.
5. Import only exact CI-verified immutable artifacts through the existing TEST
   importer/controller and verify live behavior, selected digest and cleanup.
   Keep all production, payment, mail and publication gates intact.

## Continuity and operational safety

Completed implementation children remain terminal. Use the original program and
only indispensable repository boundaries; no wrapper, observer or video-future
request chain. Preserve exact CI/merge/deployment receipts after steering.
MR 323's source head is `f081d72b4d255e0732d2d332241fd23915ba4eb0`, merge
`8b881a34c1dd7d2327e41ddf4a58f03598bc3a3f`. Its candidate is not a production
rollout, and its CI success does not validate a photo-only application artifact.

Run 11783 selected digest
`sha256:f63077c1dad36a0445855805966ba23ba713ceb415128a285f08ad5d2d9a02f2`,
registered by exact-source successful pipeline 10575 (equivalent MR pipeline
10576 also passed). TEST deployment generation 9 completed with all application
and initializer images matching. Real desktop/phone photo, GPX, painted map,
negative-video and session checks passed. A separate populated database/files
restore retained photo authorization, EXIF scrubbing and byte ranges; exact
temporary databases, files and live fixtures were removed. This is changed-backend
acceptance, not acceptance of the still-pending photo-only frontend. Managed
baseline pins preserve this release across Helm upgrades; dormant production
remains guarded and undeployed. No payment, mail, waiver assent or publication
approval is conferred.

MR 321 note 7173 explicitly ended the shared Firefox maintenance pause. A fresh
run 11785 attempt nevertheless found inconsistent control/visible-tab state and
unverified draft delivery; note 7175 records the evidence for the existing browser
reliability owner. No message send is claimed. Retain tabs, journals and bindings;
a generation change is not authorization to reclaim an uncertain binding. Check
fresh supported state before collaboration, and never retry an uncertain mutation
with a new action key. Continue independent source preparation.

No production deployment, gateway activation, live payment, routine mail, member
communication, legal assent or business-content publication is authorized here.

## Photos-only frontend TEST acceptance, run 11808

Luna delivered the separated integration revision in application MR 6. Exact-head
MR pipeline 10608 and branch pipeline 10607 passed check/build/smoke. Independent
audit verified all 34 release hashes, supplied provenance, authored JavaScript
syntax and byte-identical photo changes from the preserved draft. The source and
image omit the prototype MP4, enabled video UI and the unapproved WMATA seam.

MR 6 merged as `0e20a7cc872f8f2e304a118e8523eaef1165306c`. The normal trusted
importer verified source/pipeline/image and registered immutable digest
`sha256:01cc06f72742755c98c498b12e1e819578a527f95f6625a1b3039cbadac7d104`.
The existing authenticated TEST request and controller completed Deployment
generation 10 with one ready replica and a successful application callback.
The TEST baseline pin now preserves this artifact through platform upgrades.
The dormant production candidate retains the same-artifact source invariant;
its compile guard, zero replicas and suspended Jobs remain unchanged. Updating
that inactive pin does not deploy production or authorize promotion.

Real CA-verified Chromium checks passed on desktop and phone using temporary
synthetic membership and supplied private GPX/streams/photo inputs. Both rendered
the route line, elevation, protected photo gallery/lightbox and painted self-hosted
basemap tiles through HTTP 206. Anonymous/private and retained-video denials,
photo range reads, GPX download, logout and the two-photo/no-video homepage passed.
There were no page exceptions, external requests or horizontal overflow. Expected
console errors from explicit negative HTTP probes were counted, not called zero.
No waiver was accepted. Exact live fixtures, sessions and files were removed.

A separate populated database-and-files restore on this artifact verified exact
file-manifest parity, photo metadata scrubbing, private file/range parity and
anonymous/expired-entitlement denials. Both disposable databases and temporary
container files were removed; live member/route/media counts returned to zero.
This is not a new managed final-generation backup receipt. A subsequent bounded
run 11808 comparison reproduced truncated binary output on the legacy kubectl
exec transport despite exit zero, while WebSocket producer/receiver hashes and
bytes matched. The helper's explicit transport selection and required installed
managed capture/restore acceptance are tracked in
`joyride-test-recurring-protection.md`; this isolated photo restore does not close
that repair gate on its own. Run 11809 subsequently closed the managed repair
gate: the installed reviewed helper completed a real generation, verified its
final completion/hash readback and restored that exact database/files generation
in isolation. Installed migration/check passed and independent readback confirmed
disposable database cleanup, live DB/TLS readiness, all six selected image fields,
controller journal continuity and production namespace absence. The completed
verification Job was removed; previous final generations were untouched. Its
member database was empty and its two files were basemap files; retain the
separate populated photo-authorization evidence rather than conflating scopes.
Real Stripe acceptance is now deferred under Joy's later no-Stripe steering.
Disabled billing, WMATA display approval and remaining guarded production
contracts retain their separate current dispositions.

## No-Stripe current-phase acceptance and later activation

The current phase can finish without a Stripe account, API key, webhook secret,
product or Price ID once the revised requirements and other genuine current
requirements pass. Preserve real integration code behind the existing adapter;
do not introduce a mock-payment framework or a production billing bypass.

- Publish a nonsecret disabled capability for the authenticated frontend and
  stable explicit disabled checkout/portal/webhook outcomes. No nonexistent
  provider URL, fictitious receipt or success assertion may be returned.
- No Stripe network call, charge attempt, subscription creation, paid-member
  grant or unsigned/fabricated webhook acceptance is permitted in disabled mode.
  Worker reconciliation must no-op cleanly, not loop on disabled-provider errors.
- Preserve checkout-return ownership, verified sessions, exact versioned waiver
  and private route/photo/GPX entitlement enforcement. A waiver is not payment.
- Luna owns graceful frontend behavior and wording, delivered through the existing
  dedicated side chat and application Git/CI lane. Talon does not author their UI.
- Use only labelled isolated disposable TEST fixtures for member/waiver checks;
  never turn fixtures into a free-membership policy. Distinguish local fixture
  evidence from real provider checkout, portal, webhook delivery or reconciliation.
- Verify the exact resulting immutable TEST artifact through the existing
  importer/controller and quick installed non-payment checks. Preserve prior
  backup/photo/access receipts and avoid redundant deployments or stability soaks.

Later activation checklist, not a scheduled task or authorization:

1. LLC/account availability and Joy's chosen actual Stripe account/product/Price ID.
2. Secure TEST credential provisioning and signed webhook configuration through
   managed secret storage; never keys in chat, frontend or evidence.
3. Actual sandbox checkout, billing portal, signed idempotent webhook and
   authoritative reconciliation acceptance, including ownership and entitlement
   denial cases. Local fixtures do not satisfy these checks.
4. Separate explicit live-payment implementation/activation approval. Existing
   production deployment, public launch, mail, member communications and relevant
   business-content publication gates remain closed until separately authorized.

## Disabled-billing backend TEST acceptance, run 11814

Application MR 7 merged as `c6d79b9530c9383df613bcf27bb9d6da421adc8e`.
Exact source `0180ca6330de57fe7a540108a34a48094dbcd31a` passed check/build/smoke
in pipelines 10628 and 10629. Independent readback confirmed the image evidence
and both architectures. The normal trusted importer registered pipeline 10628;
the original receipt was preserved for the equivalent MR pipeline.

The existing authenticated TEST deployment API and controller selected digest
`sha256:a742cfd7cf2d7cdbae508e6a596a60621dedaa447a1f45c0fa8e2cb5e4b98e25`
at generation 11, with a successful terminal callback, one ready replica and all
six application/init image fields matching. Five changed installed source files
match the exact source hashes. TEST and dormant production baseline pins preserve
the exercised artifact without enabling production; no configuration or schema
migration was required. Source-only acceptance MR 337 also passed all required
jobs and merged as `f2c06430e8c46e814ff9dd3bf4c3ea85c4c1b09b`.

Five installed disabled-mode regression tests passed in a disposable in-memory
database, with provider/network guards and truthful terminal skipped-job checks.
Real CA-verified HTTPS ingress checks used a labelled synthetic non-entitled
member session: authenticated disabled capability, checkout/portal/unsigned
webhook HTTP 503, authentication and CSRF gates, return identity denial, unpaid
route/GPX denial, exact source waiver read, stale-version rejection and logout
passed. No legal assent or payment was made. Exact fixture cleanup returned
member/checkout/webhook/waiver/route/media counts to zero. Prior populated
photo/map/restore receipts remain distinct; these checks do not repeat them or
claim a new provider or frontend acceptance.

At that checkpoint the Luna handoff remained unverified because DOM and visible
composer state disagreed. The subsequent approved browser recovery and actual
frontend delivery are recorded below; this historical failure is not a current
frontend acceptance blocker. WMATA editorial/terms approval remains open and
Stripe account/provider acceptance remains deferred.

## Disabled-billing frontend TEST acceptance, run 11835

Luna delivered application MR 8 from exact source
`ca488979700427a626966115b04f9238a06c6960`. Independent source review verified
all 34 release hashes and the narrow frontend-only change. Branch pipeline 10644
and MR pipeline 10645 both passed check/build/smoke with the same immutable
multi-architecture digest. MR 8 merged as
`213a31d132ced63febcfe882d10a9ff7b11f48d1`; Luna's source branch is preserved.

The trusted importer retained its original pipeline 10644 receipt for digest
`sha256:e94453b4981897144039b80b06744d10fc367bf6ddb6c99edbeb25c0e445ebc2`.
The existing authenticated TEST API and controller completed generation 12 and
the successful terminal callback. All six application/init image fields match;
installed frontend and backend source hashes match the reviewed exact source.
The baseline pins preserve that already installed release through later platform
upgrades; the equal dormant production pin does not activate production.

Real CA/hostname-verified Chromium checks on desktop and phone verified disabled
checkout/portal buttons, Luna's closed note, zero billing POSTs, no nonmember
private-route requests, no page exceptions, no external requests and no horizontal
overflow. Separate explicitly intercepted response fixtures verified each action
becomes disabled after one 503 response and does not redirect or repeat a POST.
Those fixtures are not real provider acceptance. Initial test-harness failures
were resolved by supplying Node the installed system CA bundle and using
locator assertions rather than CSP-blocked string evaluation; no TLS bypass or
application CSP relaxation was used.

Installed HTTPS checks again verified authenticated disabled capabilities,
checkout/portal/unsigned-webhook 503, auth/CSRF enforcement, checkout-return
identity denial, unpaid route/GPX denial, exact waiver text/hash readback,
stale-version rejection and logout. No waiver was accepted and no provider or
mail action occurred. Exact synthetic fixtures were removed; independent
member/checkout/webhook/waiver/route/media counts returned to zero. Prior
populated photo/map/restore evidence remains separate and was not redundantly
repeated. Photo-only v1 and the inactive WMATA draft are unchanged.

Luna's three factual wording changes remain drafts for Joy's editorial pass,
not public-content approval. A completion acknowledgement was drafted through
the supported browser but not sent: native DOM contains it while screenshot
and accessibility again show an empty composer. No uncertain input was replayed,
no restart/recovery was attempted, and tabs/journals are preserved. The incoming
source delivery and independent TEST acceptance above are verified despite this
outgoing acknowledgement failure. Continue agent-owned dormant production
preparation; do not reopen deferred Stripe or closed frontend canaries.
