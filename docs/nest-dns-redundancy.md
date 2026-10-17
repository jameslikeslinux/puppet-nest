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

This is public DNS redundancy, not private-zone high availability. UniFi does
not serve nest or eyrie: direct queries returned NXDOMAIN. Private names on
split-DNS static clients therefore remain unavailable while Kestrel is down;
that is preferable to caching a public alternate's false negative. The exported
`/run/systemd/resolve/resolv.conf` retains upstream nameservers for kubelet,
but that flat file cannot encode split DNS. Pods and non-split-DNS DHCP clients
must not be described as having private-zone redundancy: option 6 is a server
list, not strict primary/backup routing. Such clients can retain UniFi after
failover and receive private NXDOMAIN even after Kestrel returns. Avoid treating
a successful public lookup as proof of private DNS on those consumers. Correct
private routing for arbitrary DHCP clients would require conditional forwarding
on UniFi or a separate network-aware client policy, neither supplied by option 6.

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
