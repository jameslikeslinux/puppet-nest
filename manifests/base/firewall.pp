class nest::base::firewall {
  class { 'firewalld':
    default_zone => 'drop',
  }

  # Don't manage the service state
  Service <| title == 'firewalld' |> {
    ensure => undef,
  }

  # Configure the default zone
  firewalld_zone { 'drop':
    interfaces       => [$facts['networking']['primary']],
    sources          => ['172.22.0.0/24'],
    masquerade       => true,
    purge_rich_rules => true,
    purge_services   => true,
    purge_ports      => true,
    tag              => 'default',
  }

  # Allow all VPN traffic
  firewalld_rich_rule { 'vpn':
    source => '172.22.0.0/24',
    action => accept,
  }

  # Purge direct rules
  firewalld_direct_purge { 'rule': }

  # Purge unmanaged zones
  tidy { '/etc/firewalld/zones':
    matches => [
      'block.xml*',
      'dmz.xml*',
      'external.xml*',
      'home.xml*',
      'internal.xml*',
      'public.xml*',
      'trusted.xml*',
      'work.xml*',
    ],
    recurse => 1,
    notify  => Class['firewalld::reload'],
  }
}
