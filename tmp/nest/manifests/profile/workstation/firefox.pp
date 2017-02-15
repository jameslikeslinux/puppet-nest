class nest::profile::workstation::firefox {
  # XXX: Support for 11 has been dropped.
  # Remove the next two resources after everything's been updated to 24.
  package_mask { 'www-plugins/adobe-flash':
    ensure  => absent,
    slot    => '22',
    before  => Package['www-plugins/adobe-flash'],
  }

  package { 'media-libs/hal-flash':
    ensure => absent,
  }

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
    pref("browser.tabs.remote.autostart", true);
    pref("layout.css.devPixelsPerPx", "${::nest::scaling_factor}");
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
