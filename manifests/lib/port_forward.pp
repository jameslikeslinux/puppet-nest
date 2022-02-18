define nest::lib::port_forward (
  Enum['tcp', 'udp']                $proto,
  Stdlib::Port                      $from_port,
  Stdlib::Port                      $to_port,
  Optional[Stdlib::IP::Address::V4] $from_ip4 = undef,
  Optional[Stdlib::IP::Address::V4] $to_ip4   = undef,
  Optional[Stdlib::IP::Address::V6] $from_ip6 = undef,
  Optional[Stdlib::IP::Address::V6] $to_ip6   = undef,
  Boolean                           $loopback = true,
) {
  if $to_ip4 {
    firewalld_rich_rule { "${name} (v4)":
      family       => ipv4,
      dest         => $from_ip4,
      forward_port => {
        port     => $from_port,
        protocol => $proto,
        to_addr  => $to_ip4,
        to_port  => $to_port,
      },
    }

    if $loopback {
      if $from_ip4 {
        $dest_args_ip4 = "-d ${from_ip4} "
      }

      firewalld_direct_rule { "${name} loopback (v4)":
        inet_protocol => ipv4,
        table         => nat,
        chain         => 'OUTPUT',
        priority      => 10,
        args          => "${dest_args_ip4}-p tcp --dport ${from_port} -j DNAT --to-destination ${to_ip4}:${to_port}",
      }
    }
  }

  if $to_ip6 {
    firewalld_rich_rule { "${name} (v6)":
      family       => ipv6,
      dest         => $from_ip6,
      forward_port => {
        port     => $from_port,
        protocol => $proto,
        to_addr  => $to_ip6,
        to_port  => $to_port,
      },
    }

    if $loopback {
      if $from_ip6 {
        $dest_args_ip6 = "-d ${from_ip6} "
      }

      firewalld_direct_rule { "${name} loopback (v6)":
        inet_protocol => ipv6,
        table         => nat,
        chain         => 'OUTPUT',
        priority      => 10,
        args          => "${dest_args_ip6}-p tcp --dport ${from_port} -j DNAT --to-destination ${to_ip6}:${to_port}",
      }
    }
  }
}
