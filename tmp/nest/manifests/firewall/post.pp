class nest::firewall::post {
  firewall { '9999 drop all':
    proto  => all,
    action => drop,
    before => undef,
  }

  firewall { '9999 drop all (v6)':
    proto    => all,
    action   => drop,
    before   => undef,
    provider => ip6tables,
  }

  firewallchain { 'INPUT:filter:IPv4':
    ensure => present,
    policy => drop,
  }

  firewallchain { 'INPUT:filter:IPv6':
    ensure => present,
    policy => drop,
  }
}
