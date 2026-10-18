# Pioneer maintained LTS boot paths

The normal SG2042 boot chain is ZSBL → OpenSBI → maintained LTS LinuxBoot →
kexec → maintained main LTS. Puppet installs LinuxBoot under
`/boot/riscv64/linuxboot/` and selects the complete profile through
`riscv64/boot-bundle.conf`, with `default=bundle` in `conf.ini`.

The original legacy filenames (`riscv64_Image`, `initrd.img` and
`sg2042-milkv-pioneer.dtb`) remain independent recovery inputs. Updating the
maintained first stage must not replace these files. OpenSBI and FIP are
shared platform firmware, not per-kernel trial artifacts.

At the ZSBL prompt, press `j` to enter its console:

- `boot_bundle` boots the maintained LinuxBoot profile.
- `boot_test` directly boots the maintained main LTS profile, bypassing
  LinuxBoot for development and diagnosis.
- `boot_vendor` boots the retained vendor LinuxBoot. Select the retained
  `Nest 6.12.42` entry in its menu for a complete vendor OS recovery.
- `exit` follows the configured default; it is not a vendor override.

The retained vendor menu shares the installed BLS entries and therefore does
not automatically imply that its default OS is the vendor kernel. A valid
but hung selected kernel requires external recovery; the selector does not
provide automatic post-handoff failover.

Both Linux stages need the platform MSI policy. The first-stage config
disables PCIe port services; the main kernel uses `pcie_ports=compat`.
The qualified main path also disables DRM fbdev emulation. Kestrel retains
`initcall_debug` and `loglevel=8` in both maintained stages so the external
serial capture names device and core shutdown callbacks on future attempts.
This also increases boot-time logging; it is diagnostic policy, not a reboot
hang repair. Native OpenVPN module loading follows the running kernel,
preserving legacy DCO support when booting the retained vendor kernel.

The SG2042 NVMe single-controller-page I/O limit is provisional containment
for observed indirect-PRP rejection, not proof of its underlying cause.
Keep it until a replacement is source-supported and workload-qualified.
Kestrel also disables autonomous NVMe power-state transitions in both maintained
stages while qualifying queue-timeout recovery. This policy is independent of
PCI runtime power control; keeping the PCI device active does not disable NVMe
APST. Neither containment is a claim that the underlying controller/DMA issue
has been identified.
