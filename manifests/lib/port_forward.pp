define nest::lib::port_forward (
  Stdlib::Port                      $port,
  Enum['tcp', 'udp']                $proto,
  Stdlib::IP::Address::V4           $to_addr,
  Stdlib::Port                      $to_port,
  Optional[Stdlib::IP::Address::V4] $dest     = undef,
  Boolean                           $loopback = true,
) {
  firewalld_rich_rule { $name:
    family       => ipv4,
    dest         => $dest,
    forward_port => {
      port     => $port,
      protocol => $proto,
      to_addr  => $to_addr,
      to_port  => $to_port,
    },
  }

  if $loopback {
    if $dest {
      $dest_args = "-d ${dest} "
    }

    firewalld_direct_rule { "${name}-loopback":
      inet_protocol => ipv4,
      table         => nat,
      chain         => 'OUTPUT',
      priority      => 10,
      args          => "${dest_args}-p tcp --dport ${port} -j DNAT --to-destination ${to_addr}:${to_port}",
    }
  }
}
