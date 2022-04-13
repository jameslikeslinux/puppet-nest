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
    'drop':
      interfaces => [$facts['networking']['primary']],
      masquerade => $nest::openvpn_server,
      tag        => 'default',
    ;

    'trusted':
      interfaces => ['tun0'],
      masquerade => true,
    ;
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
      'work.xml*',
    ],
    recurse => 1,
    notify  => Class['firewalld::reload'],
  }
}
