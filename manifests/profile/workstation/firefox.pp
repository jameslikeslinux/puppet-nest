class nest::profile::workstation::firefox {
  nest::portage::package_use { 'www-client/firefox':
    use => 'hwaccel',
  }

  package { [
    'www-client/firefox',
    'www-plugins/adobe-flash',
  ]:
    ensure => installed,
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

  exec { 'patch-flash-fullscreen-focus':
    command => '/bin/sed -i "s/_NET_ACTIVE_WINDOW/_XET_ACTIVE_WINDOW/g" /usr/lib64/nsbrowser/plugins/libflashplayer.so',
    onlyif  => '/bin/grep "_NET_ACTIVE_WINDOW" /usr/lib64/nsbrowser/plugins/libflashplayer.so',
    require => Package['www-plugins/adobe-flash'],
  }
}
