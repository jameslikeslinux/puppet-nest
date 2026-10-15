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

## Compatibility state

- Hawk and Gateway use their already-issued staged new-CA leaf/key, without
  rotation. Their VPN-only CA and CRL bundles contain both complete old and new
  chains. This lets them verify the still-old Kestrel server after reset.
- Kestrel retains its old VPN server leaf/key independently of its new Puppet
  agent identity. Its VPN-only CA/CRL bundles accept both old and migrated
  clients. This avoids stranding old-CA-only clients at Kestrel's reboot.
- Puppet SSL/CA files are not mixed or broadened. No old certs are revoked.
- The newly published device profiles from request ^1929 trust only the new CA.
  Their imports remain deferred: they cannot verify the retained old server
  identity. Do not represent this transitional state as device cutover success.

The signing CA fingerprints are:

- Legacy: `E1:83:F3:C8:97:F9:34:9D:E5:FB:58:37:1D:16:F8:2D:88:4D:95:6A:DA:E8:8B:7A:9E:3D:30:6E:D7:CF:D1:15`
- New: `2F:38:AB:32:14:98:AB:20:9E:3C:80:54:E3:69:AB:48:DB:D5:E5:E3:0E:9C:6F:1E:4D:04:B5:5A:EF:C0:3E:6E`

## Preparation proof and limits

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

These tests prove the proposed credential compatibility, not deployment or
post-reboot acceptance. After source deployment, independently verify the actual
production configuration, loaded identities through fresh connections, routes,
DNS and service health. Before Hawk activation, verify the alternate root's
references and protected SSL contents rather than relying on the staged image's
old Puppet-coupled OpenVPN configuration. Preserve the host's current BE and
restricted `/root/stage3-1940/vpn-before.tar` coherent rollback archive.

## Removal criteria

Keep the independent VPN credential boundary; remove only transitional trust.
Kestrel can switch to its verified new-CA server identity only after every
remaining legacy VPN client has a tested new-CA-capable trust path and recovery
access. Coordinate device profile imports with the owner; a published profile or
an established old tunnel does not prove reconnect acceptance. Test old and
migrated clients during the transition, including UDP and TCP endpoints.

Once all required clients and server endpoints reconnect using the new chain,
remove the old CA/CRLs from the VPN-only bundles and archive the old server key
through the approved credential-retention policy. Until then, retain the old
server leaf and complete CRL coverage. Never disable verification, clear failures
to pass acceptance, revoke the legacy CA, or change excluded consoles as a shortcut.
