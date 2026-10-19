# Managed Spotify rollout

## Hawk scaling follow-up

Joy subsequently reported completing Chrome consent, Spotify login and a
successful track, but the UI appeared doubled beyond the intended 2x scale.
The initial preparation notes below are historical, not current rollout status.
Nest MR 307 and overlay MR 2 have since merged and Hawk's package/launcher were
applied; dotfiles MR 55 remains Draft and unmerged.

Read-only checks found Xft DPI 192 and session GDK scale 2, with no saved Chrome
default or per-origin zoom override. The web launcher previously left Chrome's
device scale to automatic discovery. It now explicitly selects the existing
Nest GUI scale, following the managed VS Code launch convention, instead of
relying on browser/toolkit DPI discovery. This is a deterministic policy fix;
the exact browser-internal cause of the reported doubling is not established.
Native Spotify and general Chrome/Firefox settings are unchanged.

The updated isolated launcher fixture failed before the correction and passed
afterward. This proves the rendered launch argument, not the visible result.
Existing Chrome processes cannot acquire the new flag through window reuse;
owner-controlled app closure/relaunch is required before visual acceptance.
Do not terminate the active app to manufacture that check.

A subsequent canary launch confirmed actual app WM_CLASS instance
`open.spotify.com`, class `nest-spotify`. It remained on desktop 0 with the old
XMonad configuration, so music-workspace placement is still pending activation.
Read-only MPRIS discovery listed only Firefox, not a Spotify Chrome player;
this does not invalidate Joy's earlier playback report but does not establish
paused-state identity or Super+Space acceptance. No playback command, audio
restart, XMonad restart or Firefox/YTM closure was issued in this follow-up.

## Ownership and scope

Request ^1990 / task t_fa85dfa3 owns integration and delivery. This is pending
source, not a report of working playback. Explicit host Hiera enables
`nest::app::spotify` only on Falcon, Hawk, Osprey and Merlin. Native is the
default; Hawk explicitly selects `web`. No other host gains this class.

Nest owns packages and the Linux `/usr/local/bin/nest-spotify` capability.
Dotfiles MR https://gitlab.joyfullee.me/joy/dotfiles/-/merge_requests/55 owns
personal topic/window/media selection. Its tested source head is
`98a492f371a2de8c26476997760c4bdc7442cfc9`, reported pipeline 10479 passed.
Re-read that MR/head/pipeline before integration. Its separate tracked
`docs/spotify-dotfiles-integration.md` describes the proposed identities and
remaining gates. Do not merge it independently of canary verification.

## Implementation

- Falcon/Osprey: standard Gentoo `media-sound/spotify`, original vendor desktop
  entry and native integration. No forced scaling factor or GNOME policy edit.
- Hawk: standard Gentoo `www-client/google-chrome`, dedicated user-owned
  `${XDG_CONFIG_HOME:-$HOME/.config}/nest-spotify` profile and app-mode shortcut.
  This is not a genuinely installed PWA. The launcher requests X11 and exact
  class `nest-spotify`; actual class still requires live verification.
- Merlin: existing Homebrew Puppet provider installs native `spotify`.
- No login state, browser cookies or Spotify secrets are source-managed.
- The web launcher reuses a matching visible window and serializes cold starts
  with a per-user runtime lock. Actual Chrome FD handling/profile singleton and
  delayed/repeated launch behavior remain live acceptance gates.
- No playback arguments, default-browser change, autostart, session restart,
  Firefox/YTM removal or audio-routing changes are included.

## Discovery and package prerequisite

Hawk inventory-backed Bolt smoke succeeded as `joy`; host architecture is
`aarch64`. Existing XMonad process and GHC, xprop, xdotool and playerctl were
observed. No graphical activation or media command was issued.

From the assigned Nest worktree:

    bolt command run 'id -un && hostname -f; uname -m; command -v google-chrome-stable; emerge --pretend --verbose --oneshot www-client/google-chrome' --targets hawk --stream

The dry run resolves only `google-chrome-154.0.8037.57`, one new package with
existing dependencies satisfied. No Chrome binary was found. The live Gentoo
repository is snapshot `6e31dce4c8052c075689dc12b6f60584190d8c02`
(2026-09-29); Nest portage main contains the same Chrome ebuild versions.
Its Spotify ebuild is 1.2.96 (native amd64 support still needs package validation
on Falcon/Osprey before application).

Google's live repository was fetched over verified HTTPS:

    https://dl.google.com/linux/chrome/deb/dists/stable/main/binary-arm64/Packages

It advertises `google-chrome-stable` version `155.0.8059.84-1`, ARM64,
`pool/main/g/google-chrome-stable/google-chrome-stable_155.0.8059.84-1_arm64.deb`,
SHA256 `f98fcc80da576811e3212c87f53e01a367a1d05d7f7c33a013398a82a04bb00f`.
This is vendor metadata discovery, not local artifact verification or DRM proof.
Do not install the older snapshot browser merely to advance the canary.
The separate `overlay` repository must supply a reviewed current official
package before Hawk managed installation. Avoid a fleet-wide snapshot refresh
or direct deb installation for this app rollout. Recheck vendor stable/security
and exact package availability when the prerequisite returns.

## Source checks performed

    python3 spec/scripts/spotify_launcher_test.py
    git diff --check
    pdk validate

All passed at initial preparation: six isolated launcher fixtures and full PDK
validation. Fixtures render the actual ERB and replace backend executables with
private stubs; they never contact production browser/media sessions. They check
native launch, dedicated web arguments, window reuse, concurrent-launch lock,
argument rejection and absent-session failure. These are not live playback,
window-identity or Super+Space evidence. No Puppet unit suite was run.

## Required continuation

1. Finish current Chrome package prerequisite and review exact-head CI/source.
2. Publish/recheck Nest source MR and exact-head CI; inspect both MR diffs and
   current remote state before merge. Existing draft dotfiles MR is retained.
3. Deploy the reviewed source through the documented Bolt Puppet workflow.
   Stage Hawk first; inspect noop catalog and apply only intended app resources.
   Do not refresh dotfiles or start Spotify on all workstations prematurely.
4. Verify installed vendor version, ARM64 architecture, sandbox and Widevine/EME
   availability with the actual browser. Launch only the dedicated app-mode
   profile; verify exact window class, singleton and safe repeated launch.
5. Joy handles login in the actual application. Obtain authorized playback
   checkpoint before starting a track or taking over Spotify Connect; verify
   track progression and audible ROC -> Lark -> Airist output without rerouting.
6. Verify actual Chrome MPRIS identity and `xesam:url`, including paused state
   and competing Firefox/YTM media. Adjust source if the proposed dotfiles
   selector cannot distinguish intended playback safely.
7. Render and compile Falcon/Hawk XMonad with actual installed dependencies.
   Managed package apply, dotfiles source refresh/ERB render and live session
   activation are separate steps. No linked-worktree refresh helper execution.
8. Coordinate Joy's Hawk Super+Q activation explicitly; do not restart XMonad
   without fresh permission. Exercise physical Super+Space and XF86AudioPlay,
   cross-workspace pause/resume, seek and competing-player behavior on BOTH hosts.
9. After Hawk acceptance, validate/apply native packages on Falcon, Osprey and
   Merlin; verify real playback, normal launch/media controls, scaling and
   relaunch persistence without forced closure/logout/restart. Preserve YTM.
10. Record each host's source/apply/refresh/activation/playback results separately.
    Login-required or physical-input checks remain pending until actually done.

No hosts have been changed by this preparation. No playback, login, source
merge, host package installation, dotfiles refresh or XMonad restart occurred.
