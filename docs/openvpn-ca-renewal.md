# OpenVPN client certificate issuance and cutover

## Controlled production CA access

`plans/puppet/generate_cert.yaml` retains its existing plan name, but now
signs an existing locally generated CSR instead of generating/exporting private
keys on a legacy Podman server. It uses the controller's existing Kubernetes
credentials to access `default/deploy/puppet-puppetserver`, container
`puppet-puppetserver`. This is the production `puppet.eyrie` OpenVox CA, not the
`test` namespace. No autosign policy or trust settings are changed.

An operator must independently verify the signing CA's SHA256 fingerprint
before supplying it to the plan. Inspect the CA public certificate through the
controlled Kubernetes connection and compare with the intended CA endpoint.
The intermediate observed on 2026-10-14 was:

- Subject: Puppet CA generated on puppet at 2026-06-09 06:44:58 +0000
- Issuer: Puppet Root CA: 15b9523ed3cbd4
- SHA256: `2F:38:AB:32:14:98:AB:20:9E:3C:80:54:E3:69:AB:48:DB:D5:E5:E3:0E:9C:6F:1E:4D:04:B5:5A:EF:C0:3E:6E`
- Expiry: 2031-06-08 06:45:08 UTC

Inspect `puppetserver ca list --all --format json` through that same container
before any enrollment. Do not replace an existing issued or pending identity.
For each authorized client, create a fresh private key and CSR locally in a
mode-0700 private directory with umask 077. Match the CN exactly; do not add
CA-management authorization extensions. The production CA currently has
`autosign=true`: HTTP CSR submission can issue immediately, before this
helper's explicit signing gate. Do not use the HTTP enrollment endpoint for
this controlled workflow. Through the same authorized Kubernetes connection,
stage only the public CSR under the exact CA `requests/<certname>.pem` path
using exclusive creation (refuse an existing file). First check requested,
signed and revoked identities; compare the staged CSR subject and public key
with the local CSR before signing. The private profiles repository README
documents the controlled staging procedure. Do not change autosign policy,
disable TLS verification, or send the private key to the CA.

Then, from the Nest project root, sign only that pending CSR:

```sh
bolt plan run nest::puppet::generate_cert \
  name=ipad \
  ca_fingerprint=2F:38:AB:32:14:98:AB:20:9E:3C:80:54:E3:69:AB:48:DB:D5:E5:E3:0E:9C:6F:1E:4D:04:B5:5A:EF:C0:3E:6E
```

The plan refuses mismatched CA fingerprints, existing issued certificates, and
missing pending requests. It never generates, reads, or returns private keys.
This is a changed interface: `ca_fingerprint` is required and the key/CSR must
already exist. The operator must compare the pending CSR public key/subject
with the local CSR before signing; the certname alone does not authenticate
who submitted a CSR.

Retrieve only the public signed certificate and CA chain. Before profile
publication, verify the complete chain, issuer and CA fingerprint, exact CN,
client EKU/purpose, validity, and key/certificate public-key match. Preserve
all non-certificate profile bytes and template key/cert placeholders. Treat
profiles as credentials: use only the existing private repository and secured
rollback storage; never emit their contents or key-bearing diffs in logs,
reviews, or evidence artifacts. Do not copy legacy server private keys or
remove/revoke old CA certificates as part of this procedure.

## Running VPN compatibility and staged cutover

Read-only inventory-backed Bolt inspection, repeated on 2026-10-15, found Kestrel running
both `openvpn-server@nest` and `openvpn-server@nest-tcp`. Both configurations
reference `/etc/puppetlabs/puppet/ssl/certs/ca.pem`,
`/etc/puppetlabs/puppet/ssl/certs/kestrel.pem`, and the Puppet CRL.
The configured CA is still the old intermediate:

- SHA256: `E1:83:F3:C8:97:F9:34:9D:E5:FB:58:37:1D:16:F8:2D:88:4D:95:6A:DA:E8:8B:7A:9E:3D:30:6E:D7:CF:D1:15`
- Live configured leaf: CN=kestrel, issuer Puppet CA generated on puppet at
  2025-04-25 02:19:03 +0000
- Leaf expiry: 2030-12-10 06:26:35 UTC

This establishes the running service's configured oldCA files, not a packet-level
VPN handshake or proof that already-loaded process certificates match disk.
NewCA-only clients are not accepted as connection-ready against this server.
No temporary VPN connection was attempted and no device was imported.

Cutover order (requires separate authorization for running-host changes):

1. Securely retain old profiles, old router CA/leaf/key/CRL, configuration, and
   an independently usable management/recovery path. Do not revoke oldCA certs.
2. Complete and verify the Stage3 staged router root under request ^1928,
   including exact router CN/SANs, matching key, newCA chain and CRL, and both
   TCP/UDP OpenVPN configurations. Staging alone does not change the running VPN.
3. At an approved server maintenance window, migrate the router's running
   identity/trust consistently and reload/restart both OpenVPN services through
   the normal managed deployment path. Other oldCA VPN clients may also lose
   connectivity: account for them before approving the window. A mixed-trust
   transition would require its own explicit design/authorization; it is not
   silently added by this client-profile request.
4. Confirm the actual served newCA leaf and server trust, service health and
   CRL consistency. Only then import the new profiles on iPad, Pixel10a and
   Pixel8Pro, retaining the old imports for rollback.
5. Verify an actual connection on each device, remotes/fallbacks, intended
   routes and DNS. Where a controller-side probe is appropriate, bound its
   runtime and disable route/default-route/DNS/script changes. Cryptographic
   checks and OpenVPN parsing do not substitute for a real device connection.
6. If cutover fails, restore the coherent old server identity/trust/config and
   old device profiles. Keep new credentials private for a later retry; do not
   rewrite private repository history.

## Verified staged publication

Private GitLab project 45 (`joy/openvpn-profiles`, `main`) contains the renewed
profiles, full CA chain, updated template CA and controlled signing README at
commit `18e0f5b2894c5e2fca0f9ad950c56b59973d25b0`. Private visibility and exact
remote file bytes were read back. Credential-bearing files stay exclusively
in that private repository; none belong in Nest source or evidence artifacts.

The helper successfully signed the intended `ipad`, `pixel10a` and `pixel8pro`
pending CSRs with the pinned CA. Local RSA4096 keys remained private. Complete
root/intermediate/leaf verification for SSL client purpose, exact subjects,
client EKU, validity and matching key/CSR/certificate public keys passed.
Noncredential profile bytes and template cert/key placeholders were preserved.
OpenVPN parsing (`--show-ciphers`, without a tunnel) accepted every profile.
OldCA-only verification rejects the renewed leaves, as expected.

| Exact CN | Serial | Leaf expiry (UTC) |
| --- | --- | --- |
| ipad | 1B | 2031-10-14 15:51:13 |
| pixel10a | 1C | 2031-10-14 15:51:18 |
| pixel8pro | 1D | 2031-10-14 15:51:22 |

The intermediate expires first: effective chain usability ends no later than
2031-06-08 06:45:08 UTC. The existing private project has CI disabled; no private
pipeline success is claimed. The Nest helper's earlier wrong-pin and
missing-request guard checks passed, and `pdk validate` passed locally.

Rollback retains old private commit
`aba0155d6f0bdcc1157bd51b73c3d3a9a4589766` and restricted original profile
copies in the private worker's retained rollback directory. No old certificates
were revoked/deleted and no history was rewritten. Both Kestrel VPN services
remain active with oldCA public files. No server identity/trust rotation,
restart, device import or successful connection is claimed. Follow the
separately authorized cutover sequence above before importing these profiles.
