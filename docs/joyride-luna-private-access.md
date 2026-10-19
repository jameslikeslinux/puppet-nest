# Luna's isolated Joyride TEST access

This is a private app-specific endpoint, not a public gateway or permission to
reach shared Eyrie ingress. Production access and launch are outside this change.
The legacy `luna-gitlab` names are retained to preserve existing device identities,
service dependencies and GitLab transport; their bounded policy now describes
two destinations rather than a private-network route.

## Exact boundary

- Existing Muse node: `100.127.2.74`, administrator-assigned `tag:luna-gitlab`.
- Existing GitLab destination remains `172.21.2.1/32`, TCP 22 only.
- New TEST destination: `172.21.1.3/32`, TCP 443 only. This address was unused in
  live Services and belongs to the existing MetalLB test pool at discovery.
  Recheck before rollout; stop on a conflicting reservation.
- Never grant `172.21.1.0/24`, shared ingress `172.21.1.0`, default routes, DNS,
  arbitrary ports, Kestrel host access, Tailscale SSH or route auto-approval.
- Keep all existing node/tag identities, expiry and OpenVPN services unchanged.

`joyride-test-access` terminates TLS using the existing managed TEST certificate.
The pinned multi-architecture unprivileged nginx 1.30.6 image forwards only to
`joyride-test-web:8000` or the three permitted ops endpoints at
`joyride-test-ops:8001`. It cannot choose an upstream from Host, SNI, a URL or a
forwarded header. It never proxies through shared ingress. Unknown SNI fails TLS;
wrong HTTP Host returns 421. Forwarded headers are replaced, not trusted.

Only `/ops/status`, `/ops/diagnostics` and `/ops/deploy` reach the ops listener.
They still require the app's scoped single bearer token. `/delivery`, other ops
paths, roster and admin are absent from this Luna endpoint. This grants neither
member records nor controller authority. Public/member routes still enforce their
normal application authentication and entitlement boundaries.

The LoadBalancer preserves source address and accepts only Kestrel's subnet-SNAT
address `172.22.4.3/32`. An ingress NetworkPolicy repeats that constraint. Egress
is limited to the app's two ports and cluster DNS. The pod has no service-account
token, shell execution interface, application secrets, database or media mounts.
It runs nonroot with a read-only root, dropped capabilities and bounded tmpfs.
Access logging is off. TLS material remains in the managed Secret, never evidence.

## Deployment and owner gates

The kickstart authorizes narrow app integration, not broad network expansion or
impersonating an owner in an administrator/first-connection approval dialog.
Before live router/tailnet access changes, obtain the exact scoped owner decision
recorded on the parent request. Source merge alone is not network-access proof.

1. Review the exact MR and require all exact-head CI jobs, including the real
   pinned-nginx fixture check. Render through the existing declarative wrapper:

       bolt plan run nest::eyrie::deploy_joyride_test render_to=/modules/nest/.local/joyride/access-rendered.yaml

   Keep rendered output restricted; it contains runtime Secrets. Perform a
   Kubernetes server-side dry run without publishing that manifest.
2. Merge reviewed source. Deploy TEST with `nest::eyrie::deploy_joyride_test`.
   Verify the dedicated Service's exact address, ready native worker pod, TLS
   material and policies. No public DNS or production change is needed.
3. Smoke inventory-backed Bolt transport to Kestrel, deploy merged Puppet source,
   review a scoped noop and apply the existing `luna_gitlab` and `firewalld` tags.
   Inspect shared-firewall changes before proceeding. Verify actual BIRD route,
   SNAT interface address, guard rules and no-drift repeat; preserve DNS/DHCP,
   OpenVPN, BIRD, management, kernel and device enrollment.
4. Through supported secure-browser UI only, read the complete current tailnet
   policy. Stop for unrelated drift rather than overwriting another operator's
   changes. Apply the exact reviewed grant addition and approve only the new
   `172.21.1.3/32` route on the existing Kestrel router; retain GitLab's route.
   Read back the effective complete policy and route approvals. Any login,
   security challenge or Muse first-connection approval remains Joy's action.
5. In the existing dedicated Joyride side chat, ask Luna to connect via her
   existing proxy port 3130 to `172.21.1.3:443`, using TLS SNI and HTTP Host
   `joyride-test.eyrie` and normal Eyrie CA verification. Do not use `-k`, a new
   client, a broader route, a DNS grant or another conversation. The ordinary
   internal hostname keeps its existing shared-ingress DNS; this dedicated IP
   is a transport override only. Supply the existing scoped token only through
   an authorized secret intake, never a chat message or code artifact.
6. Independently verify homepage/readiness, unauthenticated status denial,
   authenticated status/diagnostics, wrong Host/SNI, absent delivery/admin/roster,
   and retained GitLab SSH. Do not approve unrelated destinations for negative
   tests. A CONNECT response alone is not HTTPS or deployment acceptance.

The real fixture command is:

    python3 spec/app/joyride/test_private_access.py

It exercises the exact nginx config/image, TLS, Host/SNI, forward-header handling,
path isolation and application-auth forwarding using explicit local fixture
upstreams. It is not proof of live router, tailnet, application or Luna success.

## Rollback and remaining work

Revoke the new TEST route approval and remove only its grant first. Restore the
GitLab-only router preference/guard/policy through reviewed source and Bolt.
Do not delete the router/device, change keys, reset Tailscale or alter OpenVPN.
Retain fail-closed filtering throughout. Recheck GitLab, DNS/DHCP, routing and
management afterwards. Deleting live Kubernetes resources remains a separate
approved operation; leaving the source-constrained isolated listener in place
without the tailnet grant does not grant Muse access.

The TEST delivery controller, preview credential provisioning, actual Luna token
intake/canary, immutable promotion/rollback and all other kickstart acceptance
remain separate work in the existing parent. This network change does not make
a queued deployment successful or authorize production/content publication.
