class nest::profile::base::firewall {
  class { '::firewall':
    # The Gentoo iptables systemd services are just oneshots
    ensure       => stopped,
    service_name => 'iptables-restore',
  }

  # Gentoo systemd services use a different save file
  File <| title == '/var/lib/iptables/rules-save6' |> {
    path => '/var/lib/ip6tables/rules-save',
  }

  service { [
    'iptables-store',
    'ip6tables-restore',
    'ip6tables-store',
  ]:
    enable => false,
  }


  #
  # Default IPv4 ruleset
  #
  firewallchain { 'INPUT:filter:IPv4':
    ensure => present,
    purge  => !str2bool($::chroot),
    ignore => 'virbr\d+',
  }

  firewall { '000 loopback':
    proto   => all,
    iniface => 'lo',
    action  => accept,
  }

  firewall { '010 related established':
    proto  => all,
    state  => ['RELATED', 'ESTABLISHED'],
    action => accept,
  }

  firewall { '011 ping':
    proto  => icmp,
    action => accept,
  }

  firewall { '999 drop all':
    proto  => all,
    action => drop,
    before => undef,
  }


  #
  # Default IPv6 ruleset
  #
  firewallchain { 'INPUT:filter:IPv6':
    ensure => present,
    purge  => !str2bool($::chroot),
  }

  firewall { '000 loopback (v6)':
    proto    => all,
    iniface  => 'lo',
    action   => accept,
    provider => ip6tables,
  }

  firewall { '010 related established (v6)':
    proto    => all,
    state    => ['RELATED', 'ESTABLISHED'],
    action   => accept,
    provider => ip6tables,
  }

  firewall { '011 icmp (v6)':
    proto    => ipv6-icmp,
    action   => accept,
    provider => ip6tables,
  }

  firewall { '999 drop all (v6)':
    proto    => all,
    action   => drop,
    before   => undef,
    provider => ip6tables,
  }
}
