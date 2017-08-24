class nest::profile::workstation::thunderbird {
  package { 'mail-client/thunderbird':
    ensure => absent,
  }

  file { '/usr/lib/thunderbird/defaults/pref/all-nest.js':
    ensure => absent,
    before => Package['mail-client/thunderbird'],
  }
}
