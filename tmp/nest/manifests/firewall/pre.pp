class nest::firewall::pre {
  Firewall {
    require => undef,
  }

  firewall { '000 loopback':
    proto   => all,
    iniface => 'lo',
    action  => accept,
  }

  firewall { '000 loopback (v6)':
    proto    => all,
    iniface  => 'lo',
    action   => accept,
    provider => ip6tables,
  }

  firewall { '010 related established':
    proto  => all,
    state  => ['RELATED', 'ESTABLISHED'],
    action => accept,
  }

  firewall { '010 related established (v6)':
    proto    => all,
    state    => ['RELATED', 'ESTABLISHED'],
    action   => accept,
    provider => ip6tables,
  }

  firewall { '011 ping':
    proto  => icmp,
    icmp   => 'echo-request',
    state  => 'NEW',
    action => accept,
  }

  firewall { '011 ping (v6)':
    proto    => ipv6-icmp,
    icmp     => 'echo-request',
    state    => 'NEW',
    action   => accept,
    provider => ip6tables,
  }
}
