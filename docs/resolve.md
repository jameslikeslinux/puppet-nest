# DaVinci Resolve on Osprey

## Shelved by default

Osprey includes `nest::app::resolve` through `nest::host::osprey`, with
`nest::app::resolve::ensure: absent` in `data/host/osprey.yaml`. The default
is also `absent`. Keep the class included: dropping it would abandon the
managed files rather than enforcing absence.

The absent catalog removes only these integration files:

- `/usr/local/share/applications/com.blackmagicdesign.resolve.desktop`
- `/usr/local/bin/resolve-startup-bridge`
- `/usr/local/share/resolve/startup-bridge.c`
- `/etc/alsa/resolve.conf`

It contains no bridge build exec. It does not recursively remove directories,
uninstall packages, launch Resolve, change audio services or modify user data.
Shared directories, GPU drivers/loaders, OpenCL/Vulkan, ALSA/PipeWire,
startup-notification and Osprey's dGPU suspend policy remain managed as before.
The GNOME hidden-entry list still names optional vendor utility desktop IDs;
its synchronizer only copies existing vendor files and removes missing ones.
The list is not a launcher or MIME association.

At shelving, the vendor application was already absent: no Resolve package
or world entry and no `/opt/resolve`. The `acct-user/systemd-resolve` and
`acct-group/systemd-resolve` packages are DNS service identities, not DaVinci.
No vendor uninstaller is needed or invoked for an already-absent installation.

## Preserved creative state

Never recursively remove `~/.local/share/DaVinciResolve` or
`~/.config/Blackmagic Design`. Project libraries/databases, media, exports,
LUTs, Fusion/Fairlight customizations, presets, licenses/activation material
and preferences remain user-owned. Unknown files are preserved, not assumed
to be disposable app residue. Re-enablement may require a compatible project
library version; back it up before allowing a newer Resolve to upgrade it.

## Deliberate re-enablement

1. Obtain the official compatible Linux x86_64 installer from Blackmagic
   Design, choosing DaVinci Resolve or Resolve Studio deliberately. Follow
   the vendor's download/registration and license terms. Studio requires a
   valid activation key or supported license dongle; retained configuration
   alone is not proof of a usable license. Do not put license bytes in Hiera.
2. Perform the vendor-supported interactive installation separately, with
   owner coordination. This module does not distribute the proprietary app,
   fetch an installer, invent a Gentoo package, accept a license, automate
   activation or promise an unattended installer. Verify the installation
   actually supplies `/opt/resolve/bin/resolve` and its vendor desktop/icon
   assets before enabling the integration. Check runtime library compatibility
   on the current Nest/Gentoo release rather than assuming vendor distro support.
3. Change `nest::app::resolve::ensure` in `data/host/osprey.yaml` to `present`.
   Keep the host class and existing shared dependencies. Validate and exercise
   `spec/classes/nest_app_resolve_spec.rb`, then use normal MR/exact-head CI,
   merge and `bolt plan run nest::puppet::deploy`.
4. Apply through the inventory-backed narrow plan:
   `bolt plan run nest::puppet::run targets=osprey tags='["nest::app::resolve"]'`.
   Reapply and check convergence. The enabled branch installs the private ALSA
   file, copies and compiles the retained C bridge, then creates the desktop entry.
5. Only with permission for a real GUI canary and no existing Resolve session,
   launch through the ordinary GNOME app entry. Independently verify dGPU
   selection, application name/icon/dock grouping, prompt startup completion,
   stable idle CPU/log rate, playback and capture. Do not interrupt an active
   creative session to test it. Setting `ensure` back to `absent` shelves the
   integration again; vendor uninstallation is a separate reviewed operation.

## Retained engineering implementation

`files/resolve/startup-bridge.c` retains the startup-notification bridge.
The launcher keeps `PrefersNonDefaultGPU=true`, `StartupWMClass=resolve` and
`StartupNotify=true`. GNOME 48's ordinary `gtk-launch` path did not inject
switcheroo-control's dGPU environment from the hint alone. The bridge execs
`switcherooctl launch` without a hard-coded GPU index, supplying
`ALSA_CONFIG_PATH=/etc/alsa/resolve.conf` to `/opt/resolve/bin/resolve`.
A bounded X11 monitor matches the real window's PID and Resolve WM_CLASS,
sets its inherited startup ID and completes the libstartup-notification
context when the window appears. Merely removing StartupWMClass trades the
busy timeout for broken dock identity; it is not the retained solution.

`files/alsa/resolve.conf` includes system ALSA/PipeWire defaults and overrides
only Resolve's literal `dmix` PCM with PipeWire. Fairlight probed card 0/device
0 even with the analog codec selected; Osprey's NVIDIA HDMI card 0 has no PCM
0. The resulting ENOENT retry/log storm burned a CPU thread. Private routing
avoids changing global ALSA card numbering. Verify both settled CPU and zero
repeated dmix-error log growth when re-enabling, not playback alone.

The C source and ALSA configuration remain current source, unchanged by
shelving. Catalog regression coverage exercises absent and present branches
without installing or launching the proprietary application.
