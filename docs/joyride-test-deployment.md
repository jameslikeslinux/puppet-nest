# Joyride private TEST deployment

## Compatible image rollout availability

TEST uses one steady-state pod plus at most one surge pod: `RollingUpdate`,
`maxUnavailable: 0`, `maxSurge: 1`, and `minReadySeconds: 10`. Both the managed
KubeCM baseline and the named-workload adapter preserve this contract. The
adapter refuses Recreate, percentage/default budgets and widened surge before
claiming work; it still patches only images and its delivery annotation using
UID/resource-version tests. An old ready pod cannot satisfy terminal success
while the replacement remains unready. A failed replacement stays failed; no
automatic schema/image rollback or deletion of the prior serving pod is added.

The two web readiness probes fetch `/sign-in`, which resolves the active frontend
through PostgreSQL and checks the manifest-bound bytes. This is stronger than
the DB-only `/health/ready`; it neither signs in nor sends email. Initializers
finish before any app listener starts. Startup probes allow two minutes for
listeners to start without premature liveness restarts. The replacement must
remain ready for ten seconds before the old pod is voluntarily removed.

All four Gunicorn listeners have a 15-second preStop endpoint-withdrawal window,
a 125-second graceful worker timeout and a 150-second pod grace budget. The ops
upload request timeout remains 120 seconds. This bounds draining, not an unlimited
connection-lifetime promise. Requests longer than the configured budgets, client
disconnects, node loss and external proxy failures remain outside that guarantee.

Overlap safety was checked against the installed favicon backend, not the older
bootstrap checkout. PostgreSQL sessions and the same managed Django secret are
shared; there is no pod-local session affinity requirement. Frontend activation
uses a shared CephFS publication lock, immutable checksum trees and a transactional
ActiveRelease pointer. Each reader resolves that pointer and serves verified
bytes. Curated content has its own shared import lock and installs its immutable
tree before committing catalog changes. Startup `--initialize-only` retains the
active curated revision; owner provisioning uses unique-email `get_or_create`
without altering verification, billing or waiver records. Basemap bootstrap uses
the already installed immutable files and does not reset an active promotion.
Missing/corrupt shared bootstrap data is a repair boundary, not permission to
delete data or race a fresh bootstrap across versions.

Workers claim rows with transactional `select_for_update(skip_locked=True)` and
lease fencing; maintenance/transit schedules use database locks and dedupe keys.
Overlap does not add a second independent schedule. This remains an at-least-once
worker: termination after an external side effect can leave work to its existing
ten-minute lease recovery. RollingUpdate is not an exactly-once email/payment
guarantee. No mail, payment, member or waiver canary is required for this rollout.

Only backward-compatible schema changes may use this ordinary path. Review all
new migrations for compatibility with the still-serving old code, lock duration
and rollback constraints before admitting the image. The existing migrate init
is retained; Kubernetes does not make destructive migrations safe. Use an
explicit expand/contract sequence or a separately planned, owner-approved
maintenance procedure for incompatible changes. Never conceal such maintenance
inside every routine release or automatically reverse a schema on timeout.

One surge adds 450 millicores and 896 MiB of requested memory (up to 5376 MiB of
container memory limits), plus its 1 GiB scratch-volume bound. The observed Kite
capacity admitted this small budget; insufficient scheduling capacity must leave
the old healthy pod serving, not relax maxUnavailable. Terminating pods can briefly
coexist with the serving/surge budget while they drain. This removes planned image
replacement gaps, not single-node, single-database, storage or ingress failures.
Production remains dormant and guarded; this is not a production HA claim.

## Owner dashboard and fast releases

The TEST baseline is application MR 29, exact-head pipeline 11263, source
`0dc66568b3f94d3c842d0150a42f7352bf0d9ed1`, merged as
`05e0042ee80b2e111d8332ce049102597d729eba`, image
`sha256:3227595c1e5c9bb99429a0e8e297bfee211b149239a9589833a824cd6c235e9d`.
It adds bounded bundle-defined galleries and mutable curated slugs. It retains
OTP-first sign-in, 90-day sessions with hourly authenticated rolling renewal,
and branded mail from `Friday Night Joyride <joy@joyridedc.com>`.
The seasonal owner dashboard and manifest-bound favicon remain included.
Frontend/content releases remain independent of this backend pin; retain Luna's
active release and all release history. The previous managed image is
`sha256:f029515f9eb433b9f6a2376faee6c77ce92faaa94c6790d7a3b99c91a4f08be9`;
read the actual installed image again before any rollback.
Internal `.eyrie` ingress and the existing private backchannel use the separate
`joyride.internal_wsgi:application` listener on port 8003. Public WSGI remains on
8000 without owner routes. Owner access requires normal verified email sign-in;
the serial `provision-owner` initializer follows migrations and creates no session.
`OWNER_EMAIL` is server-managed, not a browser-supplied identity.

For frontend/private-content-only changes, use the existing private TEST channel:
`GET /ops/releases`, `POST /ops/releases/frontend` and `POST /ops/releases/content`.
These replace image CI as the routine frontend/content iteration path; image CI
and the delivery adapter below remain for backend/dependency/legal changes.
Upload the raw gzip archive with `Content-Type: application/octet-stream`,
`X-Release-Sha256`, `X-Previous-Sha256`, `X-Release-Version` and `X-Source-Head`.
The proxy accepts only those exact methods/targets: content admits 64 MiB compressed,
while frontend remains 32 MiB. Upload/upstream and ops Gunicorn budgets stay at
120 seconds. The content importer admits at most 128 MiB of files, 16 MiB per
JPEG, 2 MiB per metadata file, 64 originals, 128 placements and 160 tar entries.
Pixel bounds are 50 MP per image, 256 MP distinct and 512 MP placement-weighted.
Frontend unpacked bounds remain unchanged. Both paths validate compare-and-swap
and exact archive contents. See application `docs/content-bundle-v2.md` for schema.
HTTP 200 with `state=succeeded` is committed activation, not an enqueued operation.
Existing bearer ops callers require `release` scope; delivery credentials do not
gain release authority. No Kubernetes credential or new publisher is introduced.

Both web listeners retain read-only data. Only the scoped ops processes get a
writable `/data/private` subpath for curated trees and `/data/private/releases`.
The existing backup scanner/archive recursively captures all of `/data/private`,
including retained release archives; its pinned implementation remains unchanged.
Both curated import dry-run and apply use `--initialize-only`, retaining an active
revision across image restarts. Rollback uses the same endpoint with a retained
archive and current SHA. Never delete editorial data/history to force startup.

Ops, trusted-test and curated-import each have a 1536 MiB memory limit; requests
remain unchanged. Sequential JPEG decoding and disk-spooled checked archives
bound processing: the compressed snapshot plus tar needs roughly 193 MiB scratch
at the cap, within the existing 1 GiB shared tmp. The 16 MiB input volume still
fetches only the immutable r1 seed, not a newer gallery. The private PVC remains
8 GiB. On the pre-deploy Kite survey, 1414 MiB was requested and 6066 MiB limited
out of about 16086 MiB allocatable; one new surge adds 896 MiB requested and
5376 MiB limited. Capacity is not permission to widen maxUnavailable.

Bootstrap uses stable curated identity independent of mutable slug; both dry-run
and apply retain `--initialize-only`. A managed backend rollout does not publish
Luna's gallery or rename editorial routes. After v2 publication, rolling back to
a pre-v2 backend first requires using the new backend to restore a compatible
legacy content archive and slug. Never perform destructive automatic rollback.

Production remains guarded and dormant. Allowlisted SMTP and sandbox billing
remain unchanged. Deployment readiness, anonymous admin denial and baseline release
status do not replace Joy mailbox/sign-in or Luna release/rollback acceptance.

## Allowlisted sign-in email

TEST enables SMTP sign-in email using the existing encrypted runtime credentials.
`TEST_MAIL_ALLOWLIST` is exactly `joy@joyfullee.me,joyfulskater@gmail.com`.
This supersedes historical routine-mail-off notes below for TEST only;
production mail and membership remain dormant. Use the normal private
`https://joyride-test.eyrie/sign-in` flow. A request accepted by the application
is distinct from successful SMTP submission, and neither proves mailbox receipt.
Never consume a recipient's sign-in link or seed an owner session to verify mail.

Joyride uses the ordinary Eyrie application boundary: personal application CI
builds an image, and Nest pins an immutable image and supplies managed runtime
credentials, storage, PostgreSQL, TLS, private access, backups and monitoring.
Luna's self-service TEST updates retain the existing small artifact importer and
deployment adapter. These are the concrete consumer of the read-only GitLab
credential and exact-workload Kubernetes role, not the withdrawn signing,
custody, supervisor or production-attestation framework. There is no new service
or connector authentication ceremony.

For a routine frontend release, Luna pushes to `joy/joyride`, inspects its normal
check/build/PostgreSQL smoke result, and uses its existing manual `preview` job
or the private Tailscale `POST /ops/deploy` endpoint. The importer checks the
successful exact-head CI and immutable multiarchitecture digest. The adapter
changes only `test/joyride-test` images, verifies readiness and reports terminal
success/failure through status. HTTP 202 alone is not deployment success.

Luna receives no host, Bolt, Kubernetes or production authority. Her authorized
Tailscale path is authentication for its scoped listener; no connector token,
synthetic identity header or extra Tailscale-side service is needed. Ordinary CI
uses its existing scoped TEST credential, not host or infrastructure secrets.

For infrastructure deployment or a durable baseline pin, inspect ordinary app
CI and image identity, update `joyride_image` in this repository through review,
then run:

    bolt plan run nest::eyrie::deploy_joyride_test

Verify the actual deployed image, completed rollout, application readiness,
sessions, private-data authorization, basemap range responses and supplied
frontend. A ready Deployment alone is not application acceptance. Keep the
previous image digest available for an explicit reviewed rollback; assess
schema compatibility before rolling application code back.

The adapter's exact initializer allowlist includes `migrate`, `basemap`,
`curated-fetch` and `curated-import`, all from the same selected application
digest. Unknown or duplicate initializers remain refused before claim. Adding
private intake without updating that allowlist caused Luna's queued r5 operation
to fail before claim with `unexpected_workload_shape`; readiness and passing CI
did not prove delivery. Preserve that queued identity and all failed receipts
while installing the correction, then verify its actual terminal outcome. Do not
delete the operation, weaken workload-shape validation or deploy around it.

The supplied frontend, database/PVC, private listener, backup and monitoring
contracts remain unchanged. Only the adapter receives exact named-workload patch
authority; this change adds no Kubernetes credential to app containers or CI.
The adapter's nonsecret journal preserves interrupted-operation identity. Its
separate delivery credential cannot perform member or production operations.

Application MR 13 removes signed production receipt consumers and the unused
evidence publisher. MR 14 moves ordinary application CI to project runner 127.
Its merged-main pipeline 10866 passed check/build/smoke and published the reviewed
multiarchitecture image pinned here, installed on TEST generation 24 by preview.
The dormant production candidate pin stays aligned but its compile guard and zero
replicas remain unchanged; this does not activate production. Production delivery
is unconditionally denied, including with legacy enable variables. Historical
database records remain for non-destructive upgrades, not new admission.

The importer also discovers running pipelines, but admits one only when required
check/build/smoke and every other job succeeded and the sole pending work is the
optional preview. This prevents registration waiting on that preview's completion.
All exact project/source/pipeline/digest and architecture checks remain. Preview
waits boundedly for registration and then the terminal controller result; inspect
its retained `test-deployment.json`, not just the pipeline badge or HTTP 202.
See the personal application's `docs/delivery-status-contract.md`.

Luna already independently deployed a benign revision through pipeline 10829,
preview retry 43584. Its first preview hit the registration race. The operator's
later rollback was not Luna rollback acceptance. The changed waiting/terminal
contract and Luna's rollback still need live verification after this deployment.
Pipeline 10866 first preview 43738 failed observation during the replacement
rollout. Retry 43759 used the same idempotency key and deployment identity and
returned terminal success. Preserve both historical receipts. Application MR 15
adds bounded transport and gateway retries without changing identity or deadlines;
authorization, malformed responses and terminal failures remain fail-closed.
Merged-main pipeline 10892 passed every job on runner 127, including preview
43885, and independently reached terminal TEST success on the baseline pinned
here. Billing remains disabled and routine mail off. Checkout binding and
authoritative reconciliation hardening passed application tests; actual sandbox
payment, waiver and member-access acceptance are still original-owner work.
Use the verified actual pre-preview artifact for rollback, not the older delivery
row's previous_digest: managed deployments and that history can differ.

Current cleanup inventory (readback before this rollout):

- Removed from Nest source: signing/custody/supervisor collection and admission
  framework. Owl reports its supervisor inactive with no loaded supervisor unit;
  the checked evidence state/configuration directories are absent.
- Removed from application source and installed TEST: signing consumer/tools/
  publisher and custom production admission in MR 13. Preserve historical audit rows.
- Kept: DB/media, TLS, encrypted runtime/provider/pull/read-only verifier secrets,
  private Tailscale listener, ordinary health/backup/restore and the small TEST
  importer/adapter needed by Luna's self-service. The public informational site
  is RETIRED under the independent 2026-10-21 retirement request.
- Kept: project runner 127, now an ordinary instance of Owl's shared manager,
  for Luna's check/build/publish/preview. It has host-root Podman engine authority,
  but no directly injected eyaml/Bolt/Puppetcore credentials. See
  `joyride-ci.md` for the trust model and cutover procedure.
  All pipeline 10866 jobs ran on it, including terminal preview. Project 83 now
  disables shared and group runners; independent readback lists only runner 127.
  Shared Nest runners are unchanged. Dedicated unused credential scope revocation
  completed in private MR 13 after source/live consumer checks: only the two
  dedicated evidence registry readers were revoked. Necessary application,
  provider, pull, verifier, delivery and runner credentials remain.

Before managed activation, inspect pending/running deployment counts and existing
journal state. Do not replay old operations. After deployment, verify exact RBAC,
healthy schedules, app readiness, denied direct/public operations, private access,
storage, backups and monitoring. Preserve historical outcomes and app data.
Production promotion/rollback remains an explicit reviewed same-artifact operator
operation with Joy's publication/activation gates, not another signing service.

This is TEST only. Joy has authorized sandbox billing using the exact TEST price
price_1USr7ARxm5b9CJTLAsfCS7RO. Runtime billing remains disabled until encrypted
provisioning, the exact webhook transport and application/frontend integration
are verified; this pin reconciliation does not enable it. Routine mail stays off.
Private MR 13 supplies the recoverable encrypted sandbox key pair. The TEST
runtime Secret now projects the existing STRIPE_SECRET_KEY and
STRIPE_PUBLISHABLE_KEY contract, rejecting non-sandbox prefixes. The official CLI listener signing secret is now encrypted in private MR 14,
with independent merged-source recovery verified. Never invent a signing secret or
register the unreachable private .eyrie URL. Stripe documents its outbound CLI
listener as an option for private testing without a public gateway; that is not
proof of registered public-endpoint delivery or production readiness.
Production member platform activation, payments, member communications and content
publication retain their separate owner gates. The existing approved public
informational site and www redirect are retired and must not be regenerated.

The TEST-only outbound listener uses the official Stripe CLI 1.54.1 pinned to
its independently inspected multiarchitecture index. It refuses live key prefixes
and compares the provider's actual device-specific signing secret with managed
configuration before forwarding. It has no Service, ingress, Kubernetes token or
RBAC. Only the sandbox API key enters the forwarding process; raw CLI output is
suppressed because startup prints the signing secret. Billing remains disabled
until transport verification; process readiness is not provider acceptance.
Forwarding targets the internal web Service with the exact allowed Host header,
not an unreachable public registration. This does not prove production delivery.

The corrected official listener is installed in TEST at Helm revision 28. Its
actual process has passed the managed signing-secret parity gate, and its narrow
network path reaches the web Service with the required Host header. The exact
application workload was restarted to consume the encrypted signing secret;
independent running-settings readback confirms its presence without exposing it.
The TEST override now enables sandbox billing with the already approved TEST
price. Production remains disabled and routine mail remains off. Genuine signed
provider delivery, payment outcomes and waiver/member unlock still require live
acceptance after this setting is deployed; listener readiness is not that proof.

Luna's updated independent canary and rollback have now passed. Her comment-only
source b530be153c8292701365676133e80a9097ab6765 passed pipeline 10895, including
terminal preview 43899, entirely on runner 127. Independently read application
state confirms forward deployment 941104ca-f6ee-440d-b136-010e26688cb3 succeeded
on sha256:65bc1b91949e727edf0f9d66a649405cb3aa52c3810c79f85e55da87a5bedfa4,
then her scoped rollback 579c6106-332a-4812-80b2-08e0dd930ca3 succeeded on the
reviewed c5786b2b baseline. Actual Kubernetes images again match that baseline.
Historical preview failures remain failures, not overwritten successes. No
production, billing or routine-mail authority was added by this canary.

## Supplied private route and photos

Application MR 18 adds TEST-only `import_curated_private`. The TEST pod fetches
only the supplied project 83 generic package `joyride-curated-private`, version
`2026-10-18-r1`, with exact size and SHA256 verification before writing its private
ephemeral input volume. Redirects are refused so the existing read-only GitLab
credential cannot follow another host. Only the fetch init mounts that credential;
web, ops and worker containers never mount the package input or reader secret.

After migration and basemap initialization, the intake init first validates with
`--dry-run`, then applies through the transactional/idempotent application command.
One supplied route (`ride-001-cathedral-climb`) and 19 member photo placements over
18 originals are installed under the existing private PVC. Other candidate tracks
stay unavailable. Original GPX and actual scout/profile are distinct supplied
inputs; no invented elevation or video. Member derivatives strip EXIF and remain
private. No public source content is published by this operation.

Startup fails closed on fetch, archive, source or existing editorial/file drift.
Do not delete a conflicting private tree or DB rows to force startup: inspect the
application's `docs/private-curated-intake.md`, retain the prior image and reconcile
the exact conflict. A rollback retains all private data and database history.
The dormant production candidate pin stays aligned, but has no intake init and
remains guarded, zero-replica and unapplied. This is not production authorization.
