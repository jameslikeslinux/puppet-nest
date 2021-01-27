class nest::role::workstation::firefox {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::lib::package_use { 'www-client/firefox':
        use => ['hwaccel', 'wifi'],
      }

      package { 'www-client/firefox':
        ensure => installed,
      }

      $webrender = $::platform ? {
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
