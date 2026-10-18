# Stage 3 VPN identity transition

Puppet agent identity replacement must not implicitly replace a management VPN's
trust or server identity. `nest::openvpn_ssl_directory` optionally points OpenVPN
at an independently provisioned SSL tree (`certs/ca.pem`, `certs/<certname>.pem`,
`private_keys/<certname>.pem`, `crl.pem`). The default remains the existing Puppet
SSL directory. Puppet manages the references, not private credential contents.

Hawk, Kestrel and Gateway use `/etc/openvpn/ssl`, protected by their reset filters.
Provision and verify this tree before applying these hosts' updated catalogs.
Keep the tree and private keys root-owned, with directory mode 0700 and file mode
0600. Never put private credentials in source, CI logs or evidence attachments.

## Compatibility state after the October 18 cutover

- Hawk and Gateway use their already-issued staged new-CA leaf/key, without
  rotation. Their VPN-only CA and CRL bundles contain both complete old and new
  chains. They have reconnected to Kestrel's new-CA server identity.
- At `2026-10-18T21:37:25Z`, Joy's authorized inventory-backed Bolt cutover
  replaced Kestrel's independent VPN leaf/key with its validated new Eyrie-issued
  identity, CN `kestrel`. TCP then UDP were restarted. Its unchanged VPN-only
  CA/CRL bundles continue to accept both old and migrated clients; service
  configurations were unchanged. VPN identity remains independent of Puppet
  agent rotation.
- Puppet SSL/CA files are not mixed or broadened. No old certs are revoked.
- The device profiles from request ^1929 trust only the new CA and no longer
  need to wait for the server cutover. Further reimports/tests remain controlled
  by Joy. Publication does not update existing device imports or prove full
  device acceptance; see [device onboarding](openvpn-ca-renewal.md#controlled-device-onboarding-and-troubleshooting).

The signing CA fingerprints are:

- Legacy: `E1:83:F3:C8:97:F9:34:9D:E5:FB:58:37:1D:16:F8:2D:88:4D:95:6A:DA:E8:8B:7A:9E:3D:30:6E:D7:CF:D1:15`
- New: `2F:38:AB:32:14:98:AB:20:9E:3C:80:54:E3:69:AB:48:DB:D5:E5:E3:0E:9C:6F:1E:4D:04:B5:5A:EF:C0:3E:6E`

The active server leaf SHA256 is
`CA:39:78:70:CF:A5:83:A6:56:FB:43:0E:D6:50:DA:01:A5:54:F4:26:D9:36:39:AD:48:EC:00:50:7F:6B:9F:F3`.
Its issuer is the new signing CA named above, not the legacy CA. This leaf
fingerprint is distinct from the signing CA fingerprints.

## Historical preparation proof and limits

Before any production switch, the rollout prepared independent identities and
verified key/leaf matches plus old/new chain, CRL and sslclient/sslserver purpose.
Fresh OpenVPN TLSv1.3 handshakes from Hawk tested both its old and new identities
against a bounded Kestrel LAN listener using the proposed server leaf/trust/CRLs.
The client checked the server EKU and exact `kestrel` name; the server checked
client EKU and both issuers. The listener used `dev null`, not server mode, so no
production client-connect/disconnect scripts, leases, DNS entries or routes were
changed. Production tunnels remained active. The listener and temporary rules
were removed and absence read back, with no failed system units on Kestrel.

The first attempt was rejected by the source-based home firewall zone: an
interface-zone rule was insufficient. The corrected source-scoped home rule
passed. This was a probe configuration failure, not a production VPN outage.

Those preparation tests proved credential compatibility, not deployment or
post-reboot acceptance. Keep that evidence distinct from the production cutover
below. Future resets still require independent checks of the alternate root's
references and protected SSL contents, loaded identities through fresh
connections, routes, DNS and service health. Preserve the recovery BE and
restricted `/root/stage3-1940/vpn-before.tar` coherent rollback archive.

## Production observations and remaining limits

Hawk and Gateway did not initially reconnect after the authorized restart. A
temporary UDP old-leaf rollback did not recover them. New credentials were
restored consistently, and Joy restarted client services through independent
access. Both had reconnected by `2026-10-18T21:55:46Z`; subsequent journals
confirmed new-root `VERIFY OK` and `Initialization Sequence Completed`. Eyrie
DNS and public Gateway GitLab HTTP 200 were verified. Caracara/Harrier UDP and
Pixel10a/iPad TCP sessions were also observed, and Joy reported both phones
working over the Internet. Full device DNS/routes/fallback/roaming acceptance
is not established by these observations.

The automatic-reconnect cause is unresolved; teardown `dco_del_peer ENOENT`
messages are not causal proof. Do not add periodic restarts, disable DCO or
change timers/firewalls speculatively. The separate phone reset loop correlated
with simultaneous connections sharing `pixel10a`; use one unique profile per
device, not `duplicate-cn`. Pixel8 Pro's Wi-Fi pre-TLS timeout was separately
resolved by Joy's OpenVPN app **Allow local network** setting, not an Android
**Block connections without VPN** change. These settings are not profile source.

The root-only pre-cutover archive on Kestrel is
`/root/openvpn-ca-cutover-20261018T213725Z/before.tar`. Keep working device imports
and rollback intact. This documentation/profile follow-up authorizes no further
VPN restart, Puppet apply, rotation, revocation or device reimport.

## Removal criteria

Keep the independent VPN credential boundary; remove only transitional trust.
Kestrel has switched to its verified new-CA server identity, but that does not
authorize removing legacy client trust. Coordinate further device profile
imports with Joy; a published profile or an established tunnel does not prove
reconnect acceptance. Test remaining old and migrated clients during the
transition, including UDP and TCP endpoints, with independent recovery access.

Once all required clients and server endpoints reconnect using the new chain,
remove the old CA/CRLs from the VPN-only bundles and archive the old server key
through the approved credential-retention policy and separately authorized
trust-removal work. Until then, retain the old server rollback credentials and
complete CRL coverage. Never disable verification, clear failures
to pass acceptance, revoke the legacy CA, or change excluded consoles as a shortcut.
