# Kubernetes API VIP health and maintenance

The API VIP is a routing contract, separate from etcd membership. A healthy etcd
quorum does not prevent an unready API advertiser from black-holing ECMP traffic.

## Desired steady state

Eyrie's intended policy advertises `172.21.255.255/32` from Control1 and Control2. Control3 remains an
etcd voter and an API server, but is not an intended VIP advertiser. API etcd
client reads still use Control3 and Control2: advertiser selection does not
silently change the measured slow-voter endpoint policy.

`nest::kubernetes::generate_kube_vip_manifest` uses kube-vip v1.2.4's native BGP
health checking. Each advertiser checks its own strict HTTPS `/readyz`, including
etcd readiness, with the Kubernetes CA mounted read-only. It does not check the
VIP, use an insecure TLS bypass, or substitute the lighter static-Pod probe.

The check period is ten seconds, timeout three seconds and withdrawal threshold
two consecutive failures. Startup suppresses advertisement until the first
successful check; recovery re-announces automatically. Detection is not instant,
and transient client failures during detection remain possible. This is not a
promise of zero-loss failover or a replacement for planned withdrawal. A shared
backend readiness failure can withdraw every gated advertiser: do not roll the
last stable management advertiser onto this policy until backend health and
the resulting route behavior are independently certified. Preserve a tested
rollback configuration throughout that transition.

Upstream manifest generation emits the CA environment setting but omits its
volume. The small manifest integration helper supplies that public-file mount
and preserves portable YAML, including the leading colon in `:2112`. Publication
is atomic through hidden temporary files. Replaced manifests are backed up
outside kubelet's watched directory under `/root/kubernetes-manifest-backups`.

## Client route ownership

BIRD owns the client kernel routes in table 100. On networkd-managed hosts,
`ManageForeignRoutes=no` keeps networkd from deleting routes owned by BIRD or
the CNI. `KeepConfiguration=static` alone does not preserve `proto bird` routes.

The Stage 3 incident exposed a separate client-side failure, not simultaneous
withdrawal by both advertisers. At 2026-10-19 21:41:05 UTC, Owl's networkd log
recorded removal of the BIRD multipath VIP route while configuring `podman1`.
Synchronized samples showed an empty kernel route, unchanged BIRD RIB entries
and Established BGP sessions. Networkd also removed a CNI blackhole route.
BIRD restored the VIP route at 21:41:31 UTC. This explains that observed route
loss, not every earlier API/backend deadline.

[Systemd's route cleanup implementation](https://github.com/systemd/systemd/blob/v262/src/network/networkd-route.c)
documents that foreign IPv4 multipath and unreachable routes cannot be assigned
to one interface during cleanup; the supported ownership setting is
`ManageForeignRoutes=no`. Global networkd configuration requires a daemon
restart, not merely `networkctl reload`. The narrowly tagged
`bird_route_ownership` Puppet resources change this setting and notify networkd.
Apply on one host only after verifying its network configuration and recovery
path; independently verify SSH, addresses, DNS, routes and networkd afterward.
Do not restart control-plane networking in parallel or touch excluded consoles.

After application, observe normal container bridge creation with simultaneous
kernel-route, BIRD-RIB, API and networkd-log checks. Do not intentionally remove
a production route to manufacture an acceptance test. A quiet interval without
bridge creation does not exercise this regression.

## Planned maintenance

Replace or withdraw one existing advertiser at a time. The Bolt plan refuses
bulk replacement/withdrawal and requires an explicit different survivor. Before
publication/removal it checks the survivor's installed VIP manifest, strict
CA-verified API readiness and a BGP route with that survivor's own next hop from
the target. A reflected route to another origin is not sufficient evidence.

For example, after independently verifying Control1 and its route:

    bolt plan run nest::kubernetes::generate_kube_vip_manifest targets=control2 vip=172.21.255.255 survivor=control1

To withdraw an advertiser intentionally:

    bolt plan run nest::kubernetes::generate_kube_vip_manifest targets=control3 vip=172.21.255.255 advertise=false survivor=control2

After each change, wait for actual static-Pod turnover if content changed,
BGP session convergence and the client's kernel next-hop set. An old mirror Pod
may briefly report Ready while its replacement is not yet available. Verify
strict direct readiness and VIP readiness, then inspect fresh logs. Do not infer
service continuity merely from a successful manifest write.

Never remove or maintain the sole surviving advertiser. Before host reset,
reboot or heavy maintenance, prove another healthy advertising path, withdraw
the target and verify client routing no longer selects it. Keep restoration
artifacts outside the watched manifest directory. Do not restore an unhealthy
member just to increase the advertiser count.

## Heavy control-plane work

No raw snapshot replication or capacity rehearsal may run unbounded on a live
control-plane member. Low-priority `nice`/`ionice` alone does not constrain ZFS
kernel memory or I/O pressure. The interrupted Control3 seed is not authorized
for automatic replay or resume by this routing repair.

Before any future capacity experiment, require an explicit bounded transfer
rate, bounded CPU/userspace memory, elapsed-time limit, exact operation receipts,
and concurrent independent API/etcd/route observations with stop criteria. Verify
those controls on the actual host; do not claim a cgroup memory cap also bounds
ZFS kernel allocation. Preserve resumable targets and snapshots after an
interruption. This document does not supply or certify a replacement transfer
implementation: that pressure-safety gate remains separate from VIP repair.

## Acceptance

Etcd client routing canaries use `nest::kubernetes::reconcile_control_plane`, one
member at a time. That plan renders only the API static manifest through
`kubeadm init phase control-plane apiserver`, using the same config and patches
for dry-run and publication. Do not substitute `kubeadm upgrade node phase
control-plane`: that broader phase can restart etcd and renew Kubernetes
certificates even when only API read endpoints were intended to change.

Require a sustained log-correlated interval with intended advertisers healthy,
correct external next hops, successful strict API and etcd proposal checks,
advancing synchronized members, no unplanned leader changes or proposal failures,
controllers retaining leases, and healthy critical workloads. Report residual
slow-apply warnings separately from API failures. Any fresh API timeout, missing
route or readiness failure must be diagnosed before control/storage rollout
continues. A canary proves only its exercised behavior, not the full fleet's
Stage 3 acceptance.
