class nest::profile::workstation::firefox {
  class use {
    package_use { 'www-client/firefox':
      use => 'gtk3',
    }
  }

  include '::nest::profile::workstation::firefox::use'

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
