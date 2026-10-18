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

## Running VPN state after the authorized cutover

The 2026-10-15 inspection recorded the old Puppet-coupled server files; that is
historical staging evidence, not the current configuration. Hawk, Gateway and
Kestrel now use independently held VPN credentials under `/etc/openvpn/ssl`,
protected from Puppet-agent identity resets. See [the Stage 3 transition](openvpn-stage3-transition.md).

At `2026-10-18T21:37:25Z`, with Joy's authorization and through inventory-backed
Bolt, Kestrel's VPN leaf/key were replaced with its validated new Eyrie-issued
identity. TCP (`openvpn-server@nest-tcp`) then UDP (`openvpn-server@nest`) were
restarted. Service configurations and dual-trust CA/CRL bundles were unchanged.

- Active leaf CN: `kestrel`
- Issuer: Puppet CA generated on puppet at 2026-06-09 06:44:58 +0000
- Leaf SHA256: `CA:39:78:70:CF:A5:83:A6:56:FB:43:0E:D6:50:DA:01:A5:54:F4:26:D9:36:39:AD:48:EC:00:50:7F:6B:9F:F3`
- Root-only pre-cutover rollback archive on Kestrel:
  `/root/openvpn-ca-cutover-20261018T213725Z/before.tar`

Hawk and Gateway initially failed to reconnect. A temporary UDP old-leaf
rollback did not recover them; the new credentials were restored consistently.
Joy restarted their client services through independent access. By
`2026-10-18T21:55:46Z`, both clients had reconnected; later journals confirmed
new-root `VERIFY OK` and `Initialization Sequence Completed`. Eyrie DNS and
public Gateway GitLab HTTP 200 were verified. Caracara/Harrier UDP and
Pixel10a/iPad TCP sessions were also observed. Joy reported both phones working
over the Internet. These checks do not establish exhaustive device DNS, route,
fallback or roaming acceptance.

The automatic-reconnect root cause remains unresolved. `dco_del_peer ENOENT`
during client teardown is an observation, not proof of cause. No periodic
restart, DCO change, timer/firewall adjustment or speculative Puppet repair is
part of this follow-up. Preserve independent VPN identity lifecycle, dual trust,
rollback and existing device imports; do not revoke legacy CAs.

## Controlled device onboarding and troubleshooting

New-CA imports no longer need to wait for the server CA cutover. Coordinate the
next reimport/test with Joy rather than replacing working phone imports remotely.

1. Obtain the intended device's profile from private project 45 only. Use
   `pixel10a.ovpn`, `pixel8pro.ovpn` and `ipad.ovpn` on their respective devices;
   do not reuse one device's certificate on another device or VPN instance.
   Simultaneous Wi-Fi and cellular connections using `pixel10a` repeatedly
   evicted one another during the investigation. Stop the unintended instance
   and import the correct unique profile; do not enable `duplicate-cn`.
2. Keep the working import available for rollback. Check that the intended
   hardened revision includes `remote-cert-tls server` and
   `verify-x509-name kestrel name` before selecting it for the controlled test.
   Existing profiles already validate the CA chain; these directives add
   explicit server-purpose and exact-name verification. Publication alone does
   not update an existing app import.
3. Check the OpenVPN app's **Allow local network** setting when Wi-Fi produces
   a pre-TLS TCP timeout. Joy confirmed this setting caused the Pixel8 Pro
   Wi-Fi-only failure. It is distinct from Android's **Block connections without
   VPN** setting; neither app setting is currently encoded by the `.ovpn` source.
4. With Joy controlling the device, test a fresh connection and server
   verification, intended DNS and routes, then Wi-Fi/cellular reconnect and
   remote fallback behavior separately. Record which checks actually ran.
   Parsing and cryptographic checks are not device acceptance. If the new import
   fails, return to the retained working import and preserve sanitized evidence;
   do not restart the server or weaken verification as an onboarding shortcut.

## Historical staged publication (2026-10-14)

Private GitLab project 45 (`joy/openvpn-profiles`, `main`) received the renewed
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
were revoked/deleted and no history was rewritten. At that staging checkpoint,
Kestrel still used the old server identity, and no server restart, device import
or successful connection was claimed. The October 18 cutover and observed
connections above supersede that checkpoint, not the preserved issuance evidence.
