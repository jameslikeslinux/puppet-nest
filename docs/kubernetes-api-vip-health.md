# Kubernetes API VIP health and maintenance

The API VIP is a routing contract, separate from etcd membership. A healthy etcd
quorum does not prevent an unready API advertiser from black-holing ECMP traffic.

## Steady state

Eyrie advertises `172.21.255.255/32` from Control1 and Control2. Control3 remains an
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
promise of zero-loss failover or a replacement for planned withdrawal.

Upstream manifest generation emits the CA environment setting but omits its
volume. The small manifest integration helper supplies that public-file mount
and preserves portable YAML, including the leading colon in `:2112`. Publication
is atomic through hidden temporary files. Replaced manifests are backed up
outside kubelet's watched directory under `/root/kubernetes-manifest-backups`.

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

Require a sustained log-correlated interval with intended advertisers healthy,
correct external next hops, successful strict API and etcd proposal checks,
advancing synchronized members, no unplanned leader changes or proposal failures,
controllers retaining leases, and healthy critical workloads. Report residual
slow-apply warnings separately from API failures. Any fresh API timeout, missing
route or readiness failure must be diagnosed before control/storage rollout
continues. A canary proves only its exercised behavior, not the full fleet's
Stage 3 acceptance.
