class nest::profile::workstation::firefox {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::lib::portage::package_use { 'www-client/firefox':
        use => 'hwaccel',
      }

      package { 'www-client/firefox':
        ensure => installed,
      }

      package { 'www-plugins/adobe-flash':
        ensure => absent,
      }

      $firefox_prefs = @("EOT")
        pref("layout.css.devPixelsPerPx", "${::nest::text_scaling_factor}");
        | EOT

      file { '/usr/lib64/firefox/defaults/pref/all-nest.js':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => $firefox_prefs,
        require => Package['www-client/firefox'],
      }

      $webrender = $::nest::video_card ? {
        'intel'  => 1,
        'nvidia' => 1,
        default  => 0,
      }

      $firefox_wrapper_content = @("EOT")
        #!/bin/bash
        GTK_USE_PORTAL=1 MOZ_USE_XINPUT2=1 MOZ_WEBRENDER=${webrender} exec /usr/lib64/firefox/firefox "$@"
        | EOT

      file { '/usr/bin/firefox':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => $firefox_wrapper_content,
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
