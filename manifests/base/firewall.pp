class nest::base::firewall {
  # Keep this filter list in sync with systemd-networkd's 20-ethernet.network
  $external_interfaces = $facts['networking']['interfaces'].keys.filter |$i| { $i =~ /^(bond|br|en|eth|usb)/ }

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
      interfaces => $external_interfaces,
      masquerade => true, # for NAT
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

  firewalld_policy {
    'nat':
      ensure        => present,
      ingress_zones => 'internal',
      egress_zones  => 'external',
      target        => 'ACCEPT',
    ;

    'port-forwarding':
      ensure        => present,
      egress_zones  => 'external',
      ingress_zones => 'internal',
      masquerade    => true,
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
