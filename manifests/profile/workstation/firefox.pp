class nest::profile::workstation::firefox {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::portage::package_use { 'www-client/firefox':
        use => 'hwaccel',
      }

      package { [
        'www-client/firefox',
        'www-plugins/adobe-flash',
      ]:
        ensure => installed,
      }

      package { 'app-admin/lastpass-binary-component':
        ensure => absent,
      }

      $firefox_prefs = @("EOT")
        pref("layout.css.devPixelsPerPx", "${::nest::text_scaling_factor}");
        | EOT

      file { '/usr/lib/firefox/defaults/pref/all-nest.js':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => $firefox_prefs,
        require => Package['www-client/firefox'],
      }

      $firefox_wrapper_content = @(EOT)
        #!/bin/bash
        MOZ_USE_XINPUT2=1 exec /usr/lib64/firefox/firefox
        | EOT

      file { '/usr/bin/firefox':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => $firefox_wrapper_content,
        require => Package['www-client/firefox'],
      }

      exec { 'patch-flash-fullscreen-focus':
        command => '/bin/sed -i "s/_NET_ACTIVE_WINDOW/_XET_ACTIVE_WINDOW/g" /usr/lib64/nsbrowser/plugins/libflashplayer.so',
        onlyif  => '/bin/grep "_NET_ACTIVE_WINDOW" /usr/lib64/nsbrowser/plugins/libflashplayer.so',
        require => Package['www-plugins/adobe-flash'],
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
