# Nest LAN public DNS redundancy

The Nest DHCP scope (172.22.4.0/24) advertises Kestrel 172.22.4.3 and
UniFi 172.22.4.1 through option 6. The option is tagged to the Nest address
range, including fixed reservations within that subnet; it is not a global
resolver override or a VPN policy. Existing leases acquire the option at their
next normal renewal. Do not bounce active links solely to refresh DNS.

Static Nest uplinks on Falcon, Owl, falcon-console and kestrel-console have the
same resolver pair, `Domains=~.` and `DNSDefaultRoute=yes`. Their separate
resolved private scope sends nest, eyrie, home and joyfullee.me only to Kestrel.
More-specific suffix routes win over the public catch-all even after resolved
selects UniFi. Kestrel itself already uses UniFi upstream; adding its own LAN
address as its upstream would create a resolver loop and is intentionally
avoided. Unrelated uplinks, containers, mobile networks and VPNs are unchanged.

This is public DNS redundancy, not private-zone high availability. UniFi's
Home Cloud Network configuration owns two persistent DNS policies of type
`Forward Domain`: `nest` and `eyrie`, both using DNS server `172.22.4.3`.
Manage these through Settings > Policy Table > DNS Records, not an unmanaged
gateway shell configuration. They are prerequisites for advertising the pair:
option 6 and kubelet's exported `/run/systemd/resolve/resolv.conf` are flat
server lists and cannot encode split DNS or strict primary/backup preference.
Without forwarding, clients selecting UniFi receive false private NXDOMAIN
even while Kestrel is healthy. Direct UniFi queries must resolve known private
names before deployment, and unknown private names must terminate locally.

Do not forward `home` or all of `joyfullee.me` to Kestrel. Kestrel already
forwards `home` to UniFi, and its general upstream is UniFi. Forwarding those
namespaces back could loop. Preserve existing UniFi host/CNAME records and
public upstream settings. The gateway policies affect only the two private
suffixes; they do not change DHCP or resolver settings on other networks.
Private Nest/Eyrie names still depend on Kestrel being available, whether
queried directly or through UniFi. Its outage must not prevent public queries
through UniFi, and its recovery must restore private resolution.

Verification should cover:

- dnsmasq syntax and an actual Nest DHCP offer's option 6, without renewing an
  active management link;
- persistent static files and effective per-link/default-route/private routing;
- ordinary stub and NSS public resolution plus HTTPS during a Kestrel outage or
  a bounded client-only failure simulation, without disrupting Kestrel;
- ordinary private resolution when Kestrel is reachable;
- kubelet's actual resolver file, management reachability, failed-unit baseline
  and a second narrowly tagged Puppet reconciliation;
- exact applied hosts and offline/unverified clients, including DHCP leases that
  have not yet renewed.

Use the canonical Bolt inventory and Puppet deployment/run plans. If private
DNS is unavailable, a temporary inventory may use source-verified addresses with
strict hostname host-key identity; never disable host-key checking. Keep the
exact original Bolt error and the corrected preflight evidence with the task.
