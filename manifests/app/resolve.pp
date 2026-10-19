# Optional integration only; the proprietary application is installed separately.
# Keep absent declared even while shelved so catalogs remove dead app helpers.
class nest::app::resolve (
  Enum['present', 'absent'] $ensure = 'absent',
) {
  if $ensure == 'present' {
    # GNOME 48's ordinary gtk-launch path did not apply the switcheroo-control
    # environment from PrefersNonDefaultGPU, so keep the hint and use the native
    # switcheroo launcher as a fallback for the executable path.
    # Resolve does not complete its startup sequence, so bridge the inherited ID
    # to its XWayland window when the real application window appears.
    $resolve_desktop_entry = @("END")
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=DaVinci Resolve
      GenericName=DaVinci Resolve
      Comment=Revolutionary new tools for editing, visual effects, color correction and professional audio post production, all in a single application!
      Path=/opt/resolve/
      Exec=/usr/local/bin/resolve-startup-bridge %u
      Terminal=false
      PrefersNonDefaultGPU=true
      MimeType=application/x-resolveproj;
      Icon=/opt/resolve/graphics/DV_Resolve.png
      StartupWMClass=resolve
      StartupNotify=true
      Name[en_US]=DaVinci Resolve
      | END

    # Fairlight probes the generic dmix PCM even when Resolve's speaker setup
    # selects the ALC294 codec. On osprey card 0 is the NVIDIA HDMI controller,
    # which has no PCM device 0, so route only Resolve's ALSA namespace through
    # the already-running PipeWire graph instead of changing global card order.
    file { '/etc/alsa':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    file { '/etc/alsa/resolve.conf':
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      source  => 'puppet:///modules/nest/alsa/resolve.conf',
      require => File['/etc/alsa'],
    }

    file { '/usr/local/share/resolve':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    file { '/usr/local/share/resolve/startup-bridge.c':
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      source  => 'puppet:///modules/nest/resolve/startup-bridge.c',
      require => File['/usr/local/share/resolve'],
    }

    exec { 'build-resolve-startup-bridge':
      command => '/bin/sh -c "cc -Wall -Wextra -Werror $(pkg-config --cflags libstartup-notification-1.0 x11) -o /usr/local/bin/resolve-startup-bridge.new /usr/local/share/resolve/startup-bridge.c $(pkg-config --libs libstartup-notification-1.0 x11) && install -m 0755 -o root -g root /usr/local/bin/resolve-startup-bridge.new /usr/local/bin/resolve-startup-bridge && rm -f /usr/local/bin/resolve-startup-bridge.new"',
      unless  => '/usr/bin/test /usr/local/bin/resolve-startup-bridge -nt /usr/local/share/resolve/startup-bridge.c',
      path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      timeout => 300,
      require => [
        File['/usr/local/share/resolve/startup-bridge.c'],
        Nest::Lib::Package['x11-libs/startup-notification'],
      ],
    }

    file { '/usr/local/share/applications/com.blackmagicdesign.resolve.desktop':
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $resolve_desktop_entry,
      require => [
        Exec['build-resolve-startup-bridge'],
        File['/etc/alsa/resolve.conf'],
        File['/usr/local/share/applications'],
      ],
    }
  } else {
    # Only app-specific managed files; never recurse into directories or user data.
    file { [
      '/usr/local/share/applications/com.blackmagicdesign.resolve.desktop',
      '/usr/local/bin/resolve-startup-bridge',
      '/usr/local/share/resolve/startup-bridge.c',
      '/etc/alsa/resolve.conf',
    ]:
      ensure => absent,
    }
  }
}
