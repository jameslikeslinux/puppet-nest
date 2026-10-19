# Joyride v1: current requirements and acceptance

Canonical program: Agent Request ^1981, task `t_befb85e8`.
This is the current Nest integration requirements/checklist, not launch approval.
Joy's photos-only steering recorded on 2026-10-19 supersedes the original
photo/video deliverable and every earlier real-scout-video pending item. The
original request and chronological reports remain historical evidence, not a
reason to require footage. Commonplace is input-only; do not alter its CI/hooks.

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

All other original requirements remain: verified email-only sessions, Stripe
Checkout/portal, signed idempotent webhooks and reconciliation, versioned verbatim
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
| Photos-only frontend | OPEN, Luna-owned | Consume Luna's next hero/member revision through existing application Git/CI integration. Verify deployed public assets and member behavior contain no enabled video UI, references or bundled clip. Talon must not edit Luna's design. |
| Backend photo-only exposure | Verified on TEST, frontend still OPEN | Application MR 5, exact source `ff6385dc43e6e99aab30880f2975842952f52bad`; run 11783 verifies installed source parity, ready-video omission/direct denial, pre-transcode processing rejection, blocked historical static clip and unchanged protected photos/ranges. Dormant schema/originals remain. |
| TEST website, sessions and protected route/photo/GPX | Prior milestone verified | Run 11770 ingress/session checks and run 11773 populated desktop/phone checks; repeat affected photo/security behavior on resulting photo-only artifact, with exact fixture cleanup. |
| Regional self-hosted basemap | Prior milestone verified | Existing checksum/region/range evidence and run 11773 painted tiles/HTTP 206; preserve self-hosted attribution/dependencies and private-route separation. |
| Luna Git/CI/backchannel | Prior milestone verified | Run 11733 actual independent Tailscale status/diagnostics/deploy success; preserve narrow trust and credentials. No new access request for closed canaries. |
| Managed SMTP identity/receipt | Approved bounded test verified | Preserve previous sender/receipt evidence; routine mail and member communications remain disabled/gated. |
| WMATA worker/cache/recovery | Prior milestone verified | Runs 11759 and 11768 managed upstream and disposable failure/backoff/recovery; metadata-only receipts. |
| WMATA member display | OPEN, backend seam delivered | Application `docs/photo-only-member-contract.md` defines the tested opt-in `<!-- joyride:wmata -->` marker, release-hashed `templates/member-wmata.html` and active-member-only escaped `wmata` context. No supplied fragment is installed. Luna owns markup, integration and editorial/terms review. No Transit Data JSON/API, raw feed export or incident-bearing handoff. |
| Stripe sandbox | UNVERIFIED | Real sandbox credentials and actual checkout/portal/webhook/reconciliation acceptance remain outstanding; mock tests do not close this. No live payments. |
| Backup/isolated restore and monitoring | Prior TEST milestone verified | Runs 11767/11768 populated restore, scheduled publication, final-generation restore, failure preservation and healthy app alerts. Keep photo authorization and restore in changed-artifact acceptance. |
| Production source preparation | PARTIAL, dormant | MR 323 merged after exact-head pipeline 10569 passed; separate zero-replica DB/PVC/listener candidate only. Compile guard remains TEST-only. See environment boundaries for missing contracts. |
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

Shared Firefox is paused for the separately owned MR 321 maintenance window.
Do not resume UI calls until its owner explicitly announces completion; retain
existing tabs, journals and bindings. A generation change is not authorization
to reclaim or recover an uncertain binding. Continue unrelated source work.

No production deployment, gateway activation, live payment, routine mail, member
communication, legal assent or business-content publication is authorized here.
