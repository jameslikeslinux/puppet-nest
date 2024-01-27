class nest::base::firewall {
  case $facts['os']['family'] {
    'Gentoo': {
      if $facts['networking']['interfaces'] and !defined(Class['nest::service::kubernetes']) {
        # Keep this filter list in sync with systemd-networkd's 20-ethernet.network
        $external_interfaces = $nest::external_interfaces.reduce(
          $facts['networking']['interfaces'].keys.filter |$i| {
            $i =~ /^(bond|br|en|eth|usb|wlan)/
          }
        ) |$memo, $i| {
          $i ? {
            /^-(.*)/ => $memo - $1,
            default  => $memo.union([$i]),
          }
        }.sort
      } else {
        $external_interfaces = []
      }

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
          sources => '172.16.0.0/12',
          target  => 'ACCEPT',
        ;

        'home':
          sources => '172.22.1.0/24',
          target  => 'default',
        ;
      }

      firewalld_policy { 'nat':
        ensure        => present,
        ingress_zones => 'internal',
        egress_zones  => 'external',
        target        => 'ACCEPT',
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

    'windows': {
      class { 'windows_firewall':
        ensure => running,
      }

      windows_firewall::exception { 'nest-icmp':
        ensure       => present,
        display_name => 'Nest ICMP',
        description  => 'Allow pings from Nest VPN',
        protocol     => 'ICMPv4',
        remote_ip    => '172.22.0.0/24',
        action       => allow,
      }

      windows_firewall::exception { 'eyrie-icmp':
        ensure       => present,
        display_name => 'Eyrie ICMP',
        description  => 'Allow pings from Eyrie network',
        protocol     => 'ICMPv4',
        remote_ip    => '172.22.4.0/24',
        action       => allow,
      }
    }
  }
}
