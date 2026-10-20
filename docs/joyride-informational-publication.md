# Joyride bounded informational publication

Joy explicitly authorized the informational business website on 2026-10-20.
This supersedes the earlier blanket publication hold for the frontend merged to
application main, not the separate full membership/payment launch gates.

## Exact content and artifact

Application source is `73c0575179ab995979f9756c6be750f4903d4781`, main pipeline
10666, with successful check 42875, build 42876 and smoke 42877. Its application
image is `registry.gitlab.joyfullee.me/joy/joyride/app@sha256:2ce05347638a8b03927eb84cb918b0eab85bc744bf24c275505b017ed70b1da2`.
The informational deployment does NOT run that financial/member application.
It serves a deterministic static projection of its exact frontend source release
`luna-frontend-v6-2026-10-20-r4`. All 21 selected files independently match the
application's release SHA256 inventory. No HTML, CSS, JavaScript, branding or copy
is edited. There is no WMATA draft, member page, sign-in script, checkout script,
map library, private GPX, original media or video in this projection.

The selected files are the approved homepage/public ride brief, their exact
assets, silhouettes, distance/elevation shape, self-hosted fonts and font licenses.
`package_informational.py` reproducibly exports this literal allowlist from the
pinned Git revision. The two JSON bundles are source-managed public artifacts packaged inside the
minimal immutable informational image, never embedded in Helm release state:
`registry.eyrie/nest/joyride-info@sha256:cca3e7b5e3ab5c8ccf57b56996e65bcea2aad39292fd1be0c49a538ef2c55efd`.
Protected-main pipeline 10700, publication job 43058, produced the image from
Nest source `a927b5745b3a7effa0019cbd9ab619c1a32855fe`; actual registry readback
verified both platforms and the pulled image's server/bundle hashes.
No credential is needed by the running site. Repack only after exact source/CI
and content-authorization review; never automatically follow a branch.

## Isolation

`nest::eyrie::deploy_joyride_info` composes ordinary KubeCM with service/app/
namespace `joyride-info`. The existing TEST and dormant full production recipes
and compile guard are untouched. Two non-root, read-only Python static servers
have no service-account token, DB, PVC, host mount, secret, mail, worker, payment
integration, ops port, delivery controller or Kubernetes authority. Only shared
Contour Envoy can reach port 8000; all pod egress is denied. No special affinity,
node selector or toleration is configured.

Only literal public paths in the packaged allowlist can return frontend bytes.
Signup and checkout-return shells return explicit disabled 503 responses;
member/API/private/ops/admin/delivery paths return 404. Mutating methods return
405. There is no registration, sign-in, session or financial operation behind
any public button, including the unchanged homepage's JOIN links. A later change
to those links or explanatory frontend copy belongs to Luna, not Talon.
The response CSP disallows connections, form submissions, external assets and
embedding. Logs do not capture queries, cookies or caller identities.

## Deployment and supervised TLS

Normal reviewed MR and required exact-head CI precede merge/deploy. Bootstrap
`nest::service::joyride_gateway` with `tls_enabled=false` first: only the exact
HTTP ACME webroot and fixed apex HTTPS redirect are installed. Obtain an apex+
www certificate with supervised Certbot webroot dry-run then live issuance;
never stop Apache or enable automatic renewal. The existing full gateway
candidate then serves the static-only normal-TLS `https://joyride.eyrie` origin
when `tls_enabled=true` is source-reviewed and applied. Host/SNI checks, existing
vhosts and mandatory origin CA/name/expiry verification stay intact.

Use inventory-backed Bolt for gateway source/apply and certificate operations;
no direct SSH deployment fallback. Validate Apache before its targeted reload.
Public DNS already resolved apex and www over IPv4 and IPv6 during discovery.
At discovery HTTPS had a hostname mismatch and the Joyride lineage did not
exist. Those findings are not successful publication verification.

## Verification and rollback

Run the real handler fixture and normal Bolt render/server dry-run. Verify actual
rollout, internal normal-TLS origin, public apex IPv4/IPv6 and www canonical
redirect, certificate chain/SAN/expiry, byte-for-byte public assets, all closed
member/signup/API/payment/ops paths and existing gateway service continuity.
Report serving source, bundle checksum, runtime image and public verification
UTC time, then notify Luna in the existing dedicated Joyride side chat.

A prior reviewed Nest revision and deterministic bundle are rollback inputs;
revert/pin those via the same KubeCM/MR path, never a mutable source branch or
financial application image. To withdraw publication, remove only this gateway
binding through source and scale only the informational deployment to zero via
reviewed KubeCM data. Keep certificates and recovery artifacts. No database or
private-media restore exists or is needed for this stateless projection.

Full v1 delivery remains open. Stripe account verification is external: website
availability is not proof that Stripe accepted it. Signup, checkout, live payments,
member entitlement, messaging and WMATA editorial activation remain deferred.
