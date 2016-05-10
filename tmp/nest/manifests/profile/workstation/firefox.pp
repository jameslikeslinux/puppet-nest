class nest::profile::workstation::firefox {
  package { [
    'www-client/firefox',
    'www-plugins/adobe-flash',
    'media-libs/hal-flash',
  ]:
    ensure => installed,
  }

  file { '/usr/lib/firefox/defaults/pref/all-nest.js':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "pref(\"layout.css.devPixelsPerPx\", \"${::nest::scaling_factor}\");\n",
    require => Package['www-client/firefox'],
  }

  exec { 'patch-flash-fullscreen-focus':
    command => '/bin/sed -i "s/_NET_ACTIVE_WINDOW/_XET_ACTIVE_WINDOW/g" /usr/lib64/nsbrowser/plugins/libflashplayer.so',
    onlyif  => '/bin/grep "_NET_ACTIVE_WINDOW" /usr/lib64/nsbrowser/plugins/libflashplayer.so',
    require => Package['www-plugins/adobe-flash'],
  }
}
