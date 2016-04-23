class nest::profile::workstation::firefox {
  nest::portage::package_use { 'www-client/firefox':
    use => 'gtk3',
  }

  package { 'www-client/firefox':
    ensure => installed,
  }

  file { '/usr/lib/firefox/defaults/pref/all-nest.js':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "pref(\"layout.css.devPixelsPerPx\", \"${::nest::scaling_factor}\");\n",
    require => Package['www-client/firefox'],
  }
}
