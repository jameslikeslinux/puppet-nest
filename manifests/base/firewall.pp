class nest::base::firewall {
  class { 'firewalld':
    default_zone => 'drop',
  }

  # Don't manage the service state
  Service <| title == 'firewalld' |> {
    ensure => undef,
  }

  # Configure the zones that this module uses
  firewalld_zone {
    'external':
      interfaces => [$facts['networking']['primary'], 'tun0'],
      target     => 'DROP',
    ;

    'internal':
      sources => '172.22.0.0/24',
      target  => 'ACCEPT',
    ;

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
