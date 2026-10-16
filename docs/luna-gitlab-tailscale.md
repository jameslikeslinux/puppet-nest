# Luna GitLab-only Tailscale canary

## Configuration ownership and boundary

Kestrel's `nest::host::kestrel::tailscale` manages the Gentoo package,
service, router preferences and host firewall. Runtime enrollment and node
keys stay outside Puppet and Git. Do not reset, reboot or upgrade Kestrel
for this canary, or replace its existing OpenVPN service.

`files/tailscale/luna-gitlab.json` is the reviewed complete effective tailnet
policy. Apply it through the Tailscale administrator UI and inspect the
complete resulting policy, including legacy ACLs and additive grants.
There is no automated policy writer. The enrollment-quarantine file is the
fail-closed rollback policy, not an alternative allow-all configuration.
The router tag must be defined before enrolling Kestrel with that tag.

Only administrator-assigned `tag:luna-gitlab` may reach `172.21.2.1/32`
on TCP 22. Assign it only to Luna's existing Muse device
`nQjHi2NSXC11CNTRL`, address `100.127.2.74`. Do not tag other devices.
The router uses `tag:kestrel-gitlab-router`. Only administrators own these
tags; neither device may assign tags, administer policy or approve routes.
Approve only the advertised `172.21.2.1/32`, never a default route or a
whole private network. No Tailscale SSH rules or route auto approvals exist.

The endpoint is Kubernetes `default/gitlab-gitlab-shell`, external TCP 22
and internal target port 2222. It is not Kestrel's shell or GitLab-test.
GitLab independently authenticates the existing external, non-admin
`@luna` account. Do not add keys, memberships or repository permissions.
Use its already-authorized `joy/commonplace` repository for read-only fetch;
never push an application change merely to test transport.

## Host confinement

The independent `inet nest_luna` nftables table runs before ordinary
firewalld filtering. It rejects all `tailscale0` host input and all forwarded
traffic except Luna's exact IPv4 source to the GitLab endpoint on TCP 22,
and established replies. It also rejects unrelated traffic towards peers.
The table is replaced atomically without flushing other tables. The guard
is required before tailscaled starts and remains installed when it stops.

Firewalld places `tailscale0` in a dedicated DROP zone. The `luna-gitlab`
policy allows only the same source/destination/port towards the internal
zone: firewalld classifies the destination into its source-defined
`172.16.0.0/12` zone before considering the external `br0` interface.
A source/destination-confined policy masquerade rule supplies subnet SNAT;
external-zone masquerade does not run on this zone pair. The independent
guard still limits that traffic to TCP 22. Tailscale's own netfilter
management is disabled to avoid a competing firewall writer.
The early guard runs before SNAT and prevents trusted private-source zones
or the router's existing trust from broadening access. This is transport
permission only: SNAT never substitutes for GitLab SSH authentication.

Kestrel already enables IPv4 forwarding for its existing router duties.
Tailscale must accept neither tailnet DNS nor other subnet routes, offer no
exit node, and run no Tailscale SSH server. The preference reconciler logs
no daemon response or enrollment URL. Enroll only after reviewing the
installed guard, preferences and full tailnet policy. No private DNS grant
is necessary: use the approved IP as the SSH destination and the verified
GitLab hostname as `HostKeyAlias`, with strict checking against an
authoritatively verified pinned host key. Never trust first-use keyscan
alone as the authority.

## Verification and safe deployment

From the repository root, use the inventory-backed Bolt transport described
in `docs/nest-bolt-worker-transport.md`. Deploy the merged exact source with
`nest::puppet::deploy`, then review a scoped noop before applying
`nest::puppet::run` to Kestrel. Include the `luna_gitlab` and `firewalld`
tags so the shared reload executes; inspect all proposed firewall changes
before accepting that scope. Repeat the scoped run and require no changes.
Do not use direct SSH or manual remote Puppet as a deployment substitute.

Before and after the apply, verify retained kernel 6.12.42, TUN, forwarding,
BIRD route to the endpoint, firewalld, dnsmasq, both OpenVPN servers,
management transport and failed system/user units. Check DNS and DHCP
service functionality rather than only unit activation. No reboot is needed.

Use the supported owner-visible Muse side chat named
`Luna - Talon GitLab connectivity diagnostics`. Luna's connector documentation
uses the runtime HTTP proxy with port changed to 3130 for Tailscale CONNECT;
ordinary runtime networking is not the tailnet path. Do not install a
second Tailscale client in Muse. Owner first-connection approvals remain
owner interactions; do not approve additional destinations for negative tests.
Keep Luna holding until router enrollment, narrow route approval and policy
readback are verified. Then verify pinned SSH authentication and a real
read-only fetch, an unauthorized repository denial, and unrelated network
and port denials. A TCP proxy acknowledgement is not proof of reaching SSH.
Record whether Kestrel reports direct or relayed traffic during that actual
canary, without inferring performance from enrollment or idle status.

Tagged-device expiry can differ by device and provider. Read both actual
expiry settings; do not silently disable expiry. An expired/revoked router
fails closed and requires administrator/owner reauthorization. Package/service
persistence and a converged catalog do not prove Muse-side connectivity.

## Revocation and rollback

1. Remove the Luna grant or restore the complete enrollment-quarantine
   policy through the admin UI, then read it back. Do not restore defaults.
2. Revoke the GitLab /32 route approval on Kestrel in Machines. Confirm no
   approved route remains; do not approve another router as a workaround.
3. Remove Luna's tagged Muse device and disconnect its Muse Tailscale
   connector when full revocation is wanted. Re-enrollment changes identity
   and requires reviewing both the tag and pinned firewall source address.
4. To retire the router, first revoke its route and device in the control
   plane. Source-manage service disablement/removal before a scoped apply;
   otherwise Puppet will restart it. Retain the fail-closed nftables guard
   until tailscaled is stopped and no traffic can enter `tailscale0`.
5. Verify OpenVPN, DNS/DHCP, BIRD and normal management still work. Neither
   rollback nor revocation changes Luna's existing GitLab HTTPS/API access.

This runbook describes the intended configuration and acceptance gates;
it is not evidence that enrollment or the end-to-end canary has passed.
