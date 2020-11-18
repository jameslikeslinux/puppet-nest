class nest::role::workstation::chromium {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::lib::portage::package_use { 'www-client/chromium':
        use => ['ozone', 'ozone-wayland', 'widevine'],
      }

      package_env { 'www-client/chromium':
        env    => 'no-debug.conf',
        before => Package['www-client/chromium'],
      }

      package { 'www-client/chromium':
        ensure => installed,
      }

      if $facts['architecture'] == 'amd64' {
        package { 'www-plugins/chrome-binary-plugins':
          ensure => installed,
        }
      }

      $xdg_session_type = '$XDG_SESSION_TYPE'
      $chromium_flags = @("EOT"/$)
        [[ $xdg_session_type == 'x11' ]] && CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --force-device-scale-factor=${::nest::gui_scaling_factor} --enable-use-zoom-for-dsf"
        CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --disable-smooth-scrolling"
        CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --enable-gpu-rasterization"
        CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --enable-oop-rasterization"
        CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --ignore-gpu-blacklist"

        # Wayland support is unstable
        CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --ozone-platform=x11"
        | EOT

      file { '/etc/chromium/nest':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => $chromium_flags,
        require => Package['www-client/chromium'],
      }

      file { [
        '/etc/chromium/gpu',
        '/etc/chromium/scaling',
        '/etc/chromium/scrolling',
      ]:
        ensure  => absent,
      }
    }

    'windows': {
      package { 'googlechrome':
        ensure => installed,
      }
    }
  }
}
