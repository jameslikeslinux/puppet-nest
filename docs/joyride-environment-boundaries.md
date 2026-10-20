# Joyride environment boundaries

## Current supported deployment

Only `service=joyride-test`, `app=joyride`, `namespace=test` and
`runtime_environment=test` are configured. The standard wrapper remains
`nest::eyrie::deploy_joyride_test`. Application health is available at
`https://joyride-test.eyrie/health/ready` with ordinary CA/hostname verification.

All existing application resources now live in
`data/kubernetes/app/joyride/test.yaml`, the namespace-specific Hiera scope.
The common `data/kubernetes/app/joyride.yaml` selects the service contract only.
`nest::service::joyride` fails compilation for any other service, namespace or
runtime environment. Changing a hostname or namespace is not a production recipe.
This is a fail-closed preparation boundary, not a production implementation or
launch approval.

The move preserves the complete TEST resource graph, image digest, private
Tailscale listener, access VIP, controller permissions/journal, importer, secrets,
worker, storage and database. TEST backup/monitor configuration remains in
`data/kubernetes/service/joyride-test.yaml`. A normal Bolt render before and after
the move produced byte-identical manifests, including the existing secret
references and selected images. Those rendered manifests contain secrets and
must not be published as evidence.

Luna's token-free capability is specific to the isolated Tailscale-authenticated
TEST path. It is not an alternative production authentication mechanism. Existing
member sessions, ordinary ops tokens and CI delivery credentials remain intact.

## Dormant production source preparation

`data/kubernetes/app/joyride/joyride.yaml` prepares a distinct `joyride` service
in namespace `joyride`. It is intentionally NOT compilable through the current
TEST-only class guard, has no production deployment wrapper, and is not deployed.
All three application Deployments have zero replicas as a second publication
barrier. These declarations are not a complete production recipe or approval.

The candidate declares separate CNPG/database storage and a separate RWX media
PVC. Web, ops and worker are separate pods: only the web Service appears in the
origin Ingress, and its NetworkPolicy admits only projectcontour Envoy on port
8000. Ops uses the ordinary authenticated port 8001 URL configuration, with a
separate Secret reference and no deployment scopes. Its NetworkPolicy currently
denies ALL ingress. There is no token-free listener, TEST access VIP, delivery
controller, RBAC, importer, verifier or journal in the candidate.

Required production-only Secret contracts (not yet provisioned):

| Secret | Keys | Consumer |
| --- | --- | --- |
| `joyride-runtime` | `DJANGO_SECRET_KEY` | web, ops, worker |
| `joyride-ops-auth` | `OPS_TOKEN` | ops only |
| `joyride-upstream` | `WMATA_API_KEY` | worker only |
| `joyride-pull` | `.dockerconfigjson` | image pull only |
| `joyride-backup-pull` | `.dockerconfigjson` | trusted Nest backup image pull only |
| `joyride-cnpg-app` | `uri` | CNPG-generated, web/ops/worker |

Generate independent signing and ops credentials through encrypted private Hiera;
never copy TEST runtime secrets. The WMATA platform credential can be reused
through managed provisioning, but cannot be exposed to web/ops or evidence.
Only read-package/read-registry scope belongs in the production pull credential.
No mail/payment/delivery credential is present; mail is disabled, Stripe is
disabled, and the exact TEST-exercised immutable application image is pinned.

`spec/app/joyride/test_production_boundaries.py` verifies these source integration
boundaries in the existing Joyride CI lane. Source fixtures do not prove runtime
network enforcement, application startup, private access, TLS or restore behavior.

The candidate declares serial `migrate` and `basemap` init containers on the web
Deployment, using the same immutable application image, non-root security context
and production-local database/signing references. Migration mounts only scratch
space. The basemap initializer reuses the existing checksum-pinned OSM installer;
only it mounts the read-only package credential and bootstrap script. Runtime
containers do not mount that credential or script, and ops/worker pods do not
carry those volumes. The installer registers the open basemap, not routes,
members, waivers or content, and does not reset an existing active map selection.
No initialization executes while replicas remain zero and the compile guard
remains closed. The shared installer has TEST evidence, not production runtime
acceptance.

The candidate also includes a suspended `joyride-monitor` CronJob, a separate
monitor-only script ConfigMap and an application-probe alert. The shared probe
helper accepts only explicit `test` or `production` targets; its default TEST
behavior is unchanged. The production target is the anonymous production web
Service on port 8000, with its explicit Host header. It checks readiness,
CSRF/session shell, current basemap metadata and HTML, refusing redirects and
bounding response size/time. It carries no runtime secret, environment, database,
media mount or service-account token. A separate same-namespace NetworkPolicy
admits only monitor-labelled pods to web port 8000; ops remains deny-all.

The alert evaluates only when this exact CronJob exists and is unsuspended, and
detects both missing and stale successful probes. Suspended source preparation
does not report a production outage. This does not test ingress TLS, browser
behavior, payments, email, worker/cache freshness, backup or notification delivery.
No production Job or rule has been deployed/evaluated; live acceptance remains
required after approved activation.

The candidate now also declares a suspended administrative `joyride-backup`
CronJob and separate helper ConfigMap. It uses the trusted Nest config image,
never a Luna-selected application image, and the established administrative
read-only host kubeconfig. That kubeconfig is privileged: the namespace allowlist
is an application safety boundary, not Kubernetes credential scope. Only this
trusted Job mounts it; application/ops/worker/monitor pods receive no such access.
Its separate pull Secret is not yet provisioned. No production backup executes
while suspended, replicas are zero and the compile guard is closed.

`backup.py` retains TEST as its default. Explicit `--environment production`
selects only namespace `joyride`, app `joyride`, CNPG `joyride-cnpg` and final
directory `/nest/backup/joyride`. Unknown environments and cross-environment
destinations are refused before capture. TEST remains fixed to its original
namespace, selectors and `/nest/backup/joyride-test` destination. Scratch is local
ephemeral storage, never the backup mount. Each generation has the same private
permissions, PostgreSQL archive validation, stable-file and app-identity checks,
hash/readback completion receipt and previous-generation preservation as TEST.
The production backup alert is gated on unsuspended state, including missing
successes. There is no automatic pruning or restore Job.

These are source and synthetic integration contracts, not production backup or
restore acceptance. Before activation, verify a real production generation and
its completion receipt, copy only to restricted local staging, validate all tar
members and hashes, and restore into a NEW disposable database and file root.
Use installed handlers to check photo/GPX authorization, metadata scrubbing,
private byte ranges and basemap parity without payments, mail or legal assent.
Never redirect live workloads, overwrite the live database/PVC, reuse TEST signing
credentials, or export archives/feeds as evidence. Remove only exact drill-created
objects and verify live continuity. The detailed isolation rules in
`joyride-test-recurring-protection.md` apply, with explicit production identity
and no implicit TEST fallback. No production capture or drill has run yet.

Before activation the candidate still needs production protection, approved
exact-artifact promotion/rollback, private TLS ops access for Joy and gateway
preparation, plus managed credentials and live initialization acceptance.
Those pieces must be implemented and
verified before the common compile guard can be widened. Do not apply this file
directly, create its namespace, scale its Deployments or copy TEST controllers.

## Remaining production implementation contract

A future reviewed implementation must establish all of the following before
widening the compile guard:

- A distinct production service and namespace, with its own DB/PVC and runtime
  secret scope. No TEST runtime signing key, ops/delivery credential, verifier
  credential or synthetic member/media fixture may become production state.
- An internal origin at `https://joyride.eyrie` whose web ingress reaches only
  the public application URL configuration on port 8000. Public gateway requests
  must never target the privileged port 8001 listener.
- An independently private, normally TLS-verified and authenticated ops/admin
  path for Joy over VPN/Tailscale. No TEST token-free port 8002, TEST access VIP,
  controller/RBAC/journal or implicit trust of LAN/cluster/forwarded headers.
- Prepared but inactive apex gateway `https://joyridedc.com` and canonical
  `www` redirect, preserving existing host checks and other gateway services.
  Public admin/ops/delivery requests must have no privileged upstream.
- Promotion and rollback of the exact tested immutable artifact, with explicit
  owner approval provenance. The existing controller is TEST-only; renaming it
  does not create an approved production controller.
- Production-specific backup/isolated-restore verification and application
  monitoring. The current TEST protection helpers are not production recipes.
- A deliberate live-payment implementation and explicit authorization before
  any live payments. The current application supports disabled/test Stripe
  modes only. No price, eligibility or legal policy is inferred from frontend
  prototype copy or credentials.

Production source preparation/review is allowed. Production deployment, gateway
activation/public launch, live payments, member communications and publication of
business content still require Joy's explicit approval of the relevant revision.
Do not create a production deployment wrapper that appears usable before the
above contracts exist. There is no approved production launch in this document.

## Latest real TEST browser evidence

Desktop and phone Chromium runs against the real HTTPS ingress used temporary
member-only fixtures from the supplied curated GPX/streams/photo package. Actual
supplied sign-in/member JavaScript exercised route-line rendering, nonempty
elevation canvas, basemap range reads and painted tiles, GPX download, gallery,
photo lightbox and, historically, prototype MP4 playback. No TLS bypass,
external map/provider requests, page errors or horizontal overflow were observed.
Anonymous route/GPX/
media reads were denied and no member media became public.

The MP4 was explicitly the supplied prototype motion-test clip, not real scout
footage. Joy subsequently excluded video from v1. This playback result is
prototype evidence only, not a v1 capability or permission to ship the clip.
No waiver was accepted and no payment/mail request was made. The exact
synthetic member, login tokens, sessions, route, media and files were removed;
independent DB readback confirmed all corresponding table counts were zero.
These engineering checks are not Joy/Luna visual, business or publication approval.
Real Stripe sandbox flows remain unverified. Real scout video is OUT OF SCOPE
FOR V1, not an outstanding verification item. Photo authorization and protection
remain in scope. The photo-only frontend revision, backend exposure closure and
resulting TEST artifact still require verification; see
[`joyride-v1-acceptance.md`](joyride-v1-acceptance.md).
