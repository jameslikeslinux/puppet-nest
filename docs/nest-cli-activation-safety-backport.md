# Nest CLI activation safety backport

The Stage 3 rollout must not boot an inactive clone with the old activation
ordering. The upstream Nest CLI fix is merged in `nest/cli` commit
`1d604b585f5aff60596d1969b0051dc3f9860f03`, but the available 0.8.0 and 0.9.0
package archives predate it. The version-scoped Portage user patches carry the
exact `lib/nest/beadm.rb` change from that commit, without changing quota policy
or deleting rollback data. Both releases have the same original BE implementation.

The backport rejects ambiguous stacked roots, disables inactive auto-mounts before
promotion, and performs target promotion before selecting the next boot. Actual
promotion still enforces ancestor and dataset quota contracts. A failure is a
stop condition, not permission to clear a quota or reboot.

## Delivery and verification

Deploy this configuration through the existing Puppet deployment plan. The
`nest_cli_safety` tag selects the existing managed Portage patch tree without
applying an entire host catalog. Inspect a no-op and apply that tag through
`nest::puppet::run` against the correct server and environment for the host.
The tag alone installs patch files; it does not rebuild an already installed
package, and does not constitute acceptance of installed CLI safety.

Rebuild the selected existing `app-admin/nest-cli` package from source with
binary-package reuse disabled. Inspect Portage's actual patch application output.
Before any native reset or activation, compare the installed BE implementation
against the merged source and exercise a read-only `nest beadm status`. If the
reset replaces the CLI with an older staged copy, the alternate root also needs
the patched package before activation/reboot. Do not assume patch-file presence,
package version, a successful reset exit or pool free space proves this condition.

Preserve current/next BE status, boot artifacts and rollback roots. Capacity,
backup, identity, reset-filter and service/quorum preflights remain mandatory;
this backport is not authorization to skip them or replay a completed reset.

## Removal criteria

Remove each version-scoped patch after that package version is no longer used by
live hosts, retained staged roots or rollback paths needing a source rebuild.
Remove the dedicated delivery tag when the fleet's supported package release
includes the upstream fix and verified installed code no longer needs a backport.
Do not apply these patches to a newer release that already contains the fix.
