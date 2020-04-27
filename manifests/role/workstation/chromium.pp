class nest::role::workstation::chromium {
  case $facts['osfamily'] {
    'Gentoo': {
      file {
        default:
          ensure => directory,
          mode   => '0644',
          owner  => 'root',
          group  => 'root',
        ;

        '/etc/portage/patches/www-client':
        ;

        '/etc/portage/patches/www-client/chromium':
          source  => 'puppet:///modules/nest/chromium/',
          recurse => true,
          purge   => true,
          before  => Package['www-client/chromium'],
        ;
      }

      nest::lib::portage::package_use { 'www-client/chromium':
        use => 'widevine',
      }

      package_env { 'www-client/chromium':
        env    => 'no-debug.conf',
        before => Package['www-client/chromium'],
      }

      package { [
        'www-client/chromium',
        'www-plugins/chrome-binary-plugins'
      ]:
        ensure  => installed,
      }

      $chromium_flags = @("EOT"/$)
        [[ ! $WAYLAND_DISPLAY ]] && CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --force-device-scale-factor=${::nest::gui_scaling_factor} --enable-use-zoom-for-dsf"
        CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --disable-smooth-scrolling"
        CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --enable-gpu-rasterization"
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
