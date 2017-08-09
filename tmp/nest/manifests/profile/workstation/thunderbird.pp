class nest::profile::workstation::thunderbird {
  package { 'mail-client/thunderbird':
    ensure => installed,
  }

  file { '/usr/lib/thunderbird/defaults/pref/all-nest.js':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "pref(\"layout.css.devPixelsPerPx\", \"${::nest::text_scaling_factor}\");\n",
    require => Package['mail-client/thunderbird'],
  }
}
