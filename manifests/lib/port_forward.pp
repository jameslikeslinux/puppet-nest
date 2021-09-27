#
# XXX Refactor or remove this class for better firewalld support
#
define nest::lib::port_forward (
  Enum['tcp', 'udp']                $proto,
  Stdlib::Port                      $from_port,
  Stdlib::Port                      $to_port,
  Optional[Stdlib::IP::Address::V4] $source_ip4      = undef,
  Optional[Stdlib::IP::Address::V4] $destination_ip4 = undef,
  Optional[Stdlib::IP::Address::V6] $source_ip6      = undef,
  Optional[Stdlib::IP::Address::V6] $destination_ip6 = undef,
) {
  if $destination_ip4 {
    firewalld_rich_rule { "${name} (v4)":
      family       => ipv4,
      dest         => $source_ip4,
      forward_port => {
        port     => $from_port,
        protocol => $proto,
        to_addr  => $destination_ip4,
        to_port  => $to_port,
      },
    }
  }

  if $destination_ip6 {
    firewalld_rich_rule { "${name} (v6)":
      family       => ipv6,
      dest         => $source_ip6,
      forward_port => {
        port     => $from_port,
        protocol => $proto,
        to_addr  => $destination_ip6,
        to_port  => $to_port,
      },
    }
  }
}
