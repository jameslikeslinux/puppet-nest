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
separate Secret reference and no deployment scopes. The dormant ops pod now has a
dedicated VPN-only TLS sidecar; its NetworkPolicy permits only the VPN source
range to that TLS port, never the shared ingress or ordinary ops port. There is
no token-free listener, TEST access VIP, delivery
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

Before activation the candidate still needs approved exact-artifact
promotion/rollback and gateway live acceptance, plus managed credentials, private
ops live acceptance, production protection and live initialization acceptance.
Those pieces must be implemented and
verified before the common compile guard can be widened. Do not apply this file
directly, create its namespace, scale its Deployments or copy TEST controllers.

### Dormant private TLS ops candidate

`joyride-ops.eyrie` is prepared as a separate source-preserving LoadBalancer
candidate at `172.21.0.2:443`, not a host/path on shared Contour. Repository and
live Service discovery found no existing allocation of that address; recheck
allocation before activation. No DNS record, namespace, Service, route, certificate
or pod has been created by this source preparation. The existing OpenVPN-pushed
`172.21.0.0/16` route covers it without expanding the VPN or Luna's Tailscale grant.
This is Joy's VPN access candidate, not a new Luna production capability.

Service `externalTrafficPolicy: Local` preserves the client source and restricts
it to the existing OpenVPN pools, collectively `172.22.0.0/24`. Both nginx's
source allowlist and NetworkPolicy repeat that range. The ops pod selects an
ordinary worker so the default MetalLB worker advertisement can reach its local
endpoint. Do not widen this to LAN/node sources to repair an unexpected SNAT:
verify routing and fail closed. IP allowlisting assumes the existing VPN/network
trust roots; it does not authenticate a particular human or defend against a
compromised router/node. Ordinary scoped bearer authentication is also mandatory.

The pinned, non-root read-only nginx sidecar has only its dedicated managed TLS
certificate, static configuration and bounded tmpfs. It has no runtime secrets,
database, media mount or service-account token. Exact SNI/Host checks reject other
origins. Only raw `GET /ops/status` and `GET /ops/diagnostics` reach the ordinary
bearer-authenticated application listener on same-pod `127.0.0.1:8001`. Wrong
methods and normalized/query variants fail closed. Other ops, admin, roster,
deployment and controller routes are absent. Caller headers are discarded except
the bearer credential; fixed internal Host/HTTPS metadata is supplied. There is
no identity injection or token-free TEST process. The ordinary listener no longer
binds the PodIP, and no Service targets port 8001. The public origin still reaches
only the separate web pod/URL configuration on port 8000.

Real pinned-nginx isolated fixtures verify exact TLS/Host/path handling, ordinary
bearer propagation, unauthorized rejection, spoofed-header removal and denial of
a non-VPN source even with the correct synthetic bearer. Positive cases substitute
only the allowlisted CIDR with the fixture's loopback; the denial case uses the
original source configuration. These are synthetic upstream fixtures, not live
VPN, Kubernetes enforcement or installed production app authentication acceptance.

After a separate approved activation, require normal CA/hostname-verified access
from Joy's actual VPN client, correct-bearer status/diagnostics, unauthenticated
and wrong-bearer denial, non-VPN/spoofed-source denial, absent public ops/admin
routes, and no direct PodIP 8001 listener. Verify all additive NetworkPolicies,
source preservation, selected certificate/endpoint/image and continuity of TEST
and existing gateway services. Provision a separate production credential through
the existing encrypted private source; never put bearer values into chat, logs,
screenshots or evidence. No such production credential or live canary exists yet.

## Remaining production implementation contract

### Installed delivery admission hardening

Application MR 10, exact source `04fcfbe9efa62a68f820ddb86ae64c5617bb9de1`,
is installed on private TEST at generation 14. Required check/build/PostgreSQL
smoke in pipeline 10665 passed. The ordinary authenticated TEST request and
existing controller selected the exact multi-architecture image, applied additive
migrations through 0005 and returned a successful terminal callback. Installed source
hashes, runtime-local queue/status, idempotent request/callback replay and negative
production enqueue were checked. No production Deployment or approval row was
created. TEST omits `PRODUCTION_DELIVERY_ENABLED`, which defaults false, and has
no approval HMAC key. The selected dormant production image remains equal to
this exercised TEST artifact; its guard and zero replicas remain unchanged.

The application now strictly imports the existing bounded signed approval receipt,
preserving exact evidence identity and immutable scope. Historical hash-only
approvals cannot authorize new delivery. Queue/result selection is runtime-local;
production rollback additionally requires prior successful production history.
Atomic approval consumption and idempotency races have disposable PostgreSQL CI
evidence, not live production acceptance. No real Joy receipt was signed/imported.

Production admission deliberately returns `trusted_test_evidence_required` without
a valid parent-issued Ed25519 installed-TEST receipt. The consumer and immutable
evidence model are installed. Nest-owned collection/signing source now exists
and real unsigned live collection passed; managed signer deployment, trust-root
provisioning and production import are not implemented. See
[`joyride-installed-test-producer.md`](joyride-installed-test-producer.md).
The exact wire contract is in the application's
`docs/installed-test-evidence.md`. The signer must bind real installation identity,
all six ordered checks and bounded observation/expiry, never CI alone.
No signing key or public trust root is configured in TEST. Installed negative
checks verified that TEST rejects proof import before opening the receipt file,
cannot supply production evidence, and rejects empty proof. No evidence, owner
approval or production row was created. These are fail-closed TEST observations,
not a positive trusted producer/import/production-admission canary.

A CI receipt, locally inserted TEST deployment row, agent-authored evidence label
or synthetic HMAC signature cannot replace it or Joy's actual exact-action
approval. The existing TEST importer/controller must not acquire production
authority. Distinct trusted proof import, Joy provenance/import isolation and
production controller/topology remain engineering prerequisites before activation;
do not enable delivery or widen the compile guard to work around their absence.

### Dormant public gateway candidate

`nest::service::joyride_gateway` and
`files/app/joyride/production-gateway-apache.conf` prepare Apache configuration
using the existing gateway's IPv4/IPv6 addresses and Apache resource conventions.
Neither gateway host data nor any active class includes it. Adding source does
not create DNS, request a certificate, change a firewall, reload Apache or expose
the application. Do not include the class before separately approved activation.
The existing gateway's host map and global `StrictHostCheck` are unchanged.

The candidate requires a supervised certificate at the existing Let's Encrypt
path covering BOTH apex and `www`. HTTP provides only the restricted ACME webroot
exception and a fixed apex HTTPS redirect. HTTPS `www` also redirects to the
fixed apex, retaining path/query. Exact Host/SNI checks reject mismatches and
unconfigured hosts. The only proxy destination is `https://joyride.eyrie/`,
with mandatory trusted chain, peer-name and expiry verification against the
system CA bundle. It cannot address the private ops Service or ports 8001/8002.
Normalized ops/admin/delivery prefixes are denied before proxying; encoded
slashes remain disabled. Public session/CSRF/Origin/Range headers survive, but
caller forwarding and TEST/Tailscale identity headers are removed and HTTPS
metadata is fixed. It does not grant a member entitlement or approve content.
Access logging is disabled per vhost to avoid member login query/cookie capture;
error verbosity is critical-only. Application monitoring remains separate.

`test_production_gateway.py` exercises real digest-pinned Apache with an isolated
synthetic TLS origin and client. It verifies apex/HTTP redirects, path/query,
Host/SNI rejection, normalized private-path denial, session/CSRF/range propagation,
spoofed-header removal and rejection of both a trusted wrong-name certificate
and a correct-name untrusted certificate. Double-encoded paths remain encoded,
not twice-decoded into privileged paths. Only fixture addresses/ports and
certificates differ. These fixtures do NOT establish live gateway TLS, Gentoo
Apache module parity, DNS, Kubernetes/origin policy or application acceptance.

Before approved activation: verify exact certificate SANs/chain/expiry and origin
TLS from the inventory-backed gateway path; render/validate the full Apache
configuration alongside existing vhosts; inspect additive network policies and
upstream listener selection; then apply through normal reviewed Puppet/Bolt.
Require actual apex/`www` TLS, member/CSRF/range behavior, negative public
ops/admin/delivery and Host probes, non-public TEST, and existing-service continuity.
Do not obtain certificates, change DNS, include this class or run that apply as
part of dormant source preparation. No production wrapper or compile-guard
widening is introduced.

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
