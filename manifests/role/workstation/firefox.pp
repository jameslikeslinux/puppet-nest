class nest::role::workstation::firefox {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::lib::package_use { 'www-client/firefox':
        use => 'hwaccel',
      }

      package { 'www-client/firefox':
        ensure => installed,
      }

      file { '/usr/lib64/firefox/defaults/pref/all-scaling.js':
        ensure => absent,
      }

      $webrender = $::platform ? {
        'raspberrypi' => 0,
        default       => 1,
      }

      file { '/usr/bin/firefox':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => template('nest/firefox/wrapper.erb'),
        require => Package['www-client/firefox'],
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
