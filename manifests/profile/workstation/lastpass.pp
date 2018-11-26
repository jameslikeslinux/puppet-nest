class nest::profile::workstation::lastpass {
  package { 'app-admin/lastpass-cli':
    ensure => absent,
  }

  file { '/home/james/.lastpass':
    ensure  => absent,
    recurse => true,
    force   => true,
  }
}
