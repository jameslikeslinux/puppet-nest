class nest::role::workstation::firefox {
  case $facts['osfamily'] {
    'Gentoo': {
      # clang-11: error: the clang compiler does not support '-mcpu=cortex-a72.cortex-a53+crypto'
      if defined(File['/etc/portage/env/no-big-little.conf']) {
        package_env { 'www-client/firefox':
          env    => 'no-big-little.conf',
          before => Nest::Lib::Package_use['www-client/firefox'],
        }
      }

      nest::lib::package_use { 'www-client/firefox':
        use => ['hwaccel'],
      }

      package { 'www-client/firefox':
        ensure => installed,
      }

      $webrender = $facts['profile']['platform'] ? {
        'raspberrypi' => 0,
        default       => 1,
      }

      $autoconfig_content = @(AUTOCONFIG)
        pref("general.config.filename", "firefox.cfg");
        pref("general.config.obscure_value", 0);
        | AUTOCONFIG

      file {
        default:
          owner   => 'root',
          group   => 'root',
          require => Package['www-client/firefox'],
        ;

        '/usr/local/bin/firefox':
          mode    => '0755',
          content => template('nest/firefox/wrapper.erb'),
        ;

        '/usr/local/bin/firefox-wayland':
          mode   => '0755',
          source => 'puppet:///modules/nest/firefox/firefox-wayland',
        ;

        '/usr/local/bin/firefox-x11':
          mode   => '0755',
          source => 'puppet:///modules/nest/firefox/firefox-x11',
        ;

        '/usr/lib64/firefox/firefox.cfg':
          mode    => '0644',
          content => template('nest/firefox/firefox.cfg.erb'),
        ;

        '/usr/lib64/firefox/defaults/pref/autoconfig.js':
          mode    => '0644',
          content => $autoconfig_content,
        ;

        '/usr/lib64/firefox/defaults/pref/all-nest.js':
          ensure => absent,
        ;
      }
    }

    'windows': {
      package { 'firefox':
        ensure => installed,
      }

      file {
        default:
          owner => 'james',
        ;

        'C:/Users/james/AppData/Roaming/Mozilla':
          ensure => directory,
        ;

        'C:/Users/james/AppData/Roaming/Mozilla/Firefox':
          ensure => link,
          target => 'C:/tools/cygwin/home/james/.mozilla/firefox',
        ;
      }
    }
  }
}
