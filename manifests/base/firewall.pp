class nest::base::firewall {
  class { 'firewalld':
    default_zone => 'drop',
  }

  # Don't manage the service state
  Service <| title == 'firewalld' |> {
    ensure => undef,
  }

  # Configure the zones that this module uses
  # See https://www.linuxjournal.com/content/understanding-firewalld-multi-zone-configurations
  firewalld_zone {
    # Control access to managed interfaces, dropping by default
    'external':
      interfaces => [$facts['networking']['primary'], 'tun0'],
      target     => 'DROP',
    ;

    # Accept all VPN traffic
    'internal':
      sources => '172.22.0.0/24',
      target  => 'ACCEPT',
    ;

    # Pass home packets to interface zone (external), otherwise REJECT
    'home':
      sources => '172.22.1.0/24',
      target  => 'default',
    ;
  }

  # Purge direct rules
  firewalld_direct_purge { 'rule': }

  # Purge unmanaged zones
  tidy { '/etc/firewalld/zones':
    matches => [
      'block.xml*',
      'dmz.xml*',
      'drop.xml*',
      'public.xml*',
      'trusted.xml*',
      'work.xml*',
    ],
    recurse => 1,
    notify  => Class['firewalld::reload'],
  }
}
