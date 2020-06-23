class nest::role::workstation::firefox {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::lib::portage::package_use { 'www-client/firefox':
        use => 'hwaccel',
      }

      # Something about elf-hack enabled by debug flags and not working on arm64
      if $facts['architecture'] == 'aarch64' {
        package_env { 'www-client/firefox':
          env    => 'no-debug.conf',
          before => Package['www-client/firefox'],
        }
      }

      package { 'www-client/firefox':
        ensure => installed,
      }

      file { '/usr/lib64/firefox/defaults/pref/all-scaling.js':
        ensure => absent,
      }

      $webrender = $::nest::video_card ? {
        'intel'  => 1,
        'nvidia' => 1,
        default  => 0,
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
