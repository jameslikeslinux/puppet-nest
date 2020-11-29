class nest::role::workstation::firefox {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::lib::package_use { 'www-client/firefox':
        use => 'hwaccel',
      }

      package { 'www-client/firefox':
        ensure => installed,
      }

      $webrender = $::platform ? {
        'raspberrypi' => 0,
        default       => 1,
      }

      file {
        default:
          owner   => 'root',
          group   => 'root',
          require => Package['www-client/firefox'],
        ;

        '/usr/bin/firefox':
          mode    => '0755',
          content => template('nest/firefox/wrapper.erb'),
        ;

        '/usr/lib64/firefox/defaults/pref/all-nest.js':
          mode    => '0644',
          content => template('nest/firefox/all-nest.js.erb'),
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
