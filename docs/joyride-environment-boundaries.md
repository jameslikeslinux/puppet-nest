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

## Production implementation contract, not yet configured

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
photo lightbox and prototype MP4 playback. No TLS bypass, external map/provider
requests, page errors or horizontal overflow were observed. Anonymous route/GPX/
media reads were denied and no member media became public.

The MP4 is explicitly the supplied prototype motion-test clip, not real scout
footage. No waiver was accepted and no payment/mail request was made. The exact
synthetic member, login tokens, sessions, route, media and files were removed;
independent DB readback confirmed all corresponding table counts were zero.
These engineering checks are not Joy/Luna visual, business or publication approval.
Real Stripe sandbox flows and real scout video remain unverified.
