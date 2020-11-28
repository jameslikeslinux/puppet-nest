define nest::lib::port_forward (
  Stdlib::Port                      $port,
  Enum['tcp', 'udp']                $proto,
  Optional[Stdlib::IP::Address::V4] $source_ip4,
  Optional[Stdlib::IP::Address::V4] $destination_ip4,
  Optional[Stdlib::IP::Address::V6] $source_ip6,
  Optional[Stdlib::IP::Address::V6] $destination_ip6,
) {
  if $source_ip4 and $destination_ip4 {
    firewall {
      default:
        provider => iptables,
      ;

      "100 ${name} dnat (v4)":
        table       => nat,
        chain       => 'PREROUTING',
        destination => $source_ip4,
        proto       => $proto,
        dport       => $port,
        jump        => 'DNAT',
        todest      => $destination_ip4,
      ;

      "100 ${name} (v4)":
        chain       => 'FORWARD',
        destination => $destination_ip4,
        proto       => $proto,
        dport       => $port,
        action      => accept,
      ;

      "100 ${name} snat (v4)":
        table       => nat,
        chain       => 'POSTROUTING',
        destination => $destination_ip4,
        proto       => $proto,
        sport       => $port,
        jump        => 'SNAT',
        tosource    => $source_ip4,
      ;
    }
  }

  if $source_ip6 and $destination_ip6 {
    firewall {
      default:
        provider => ip6tables,
      ;

      "100 ${name} dnat (v6)":
        table       => nat,
        chain       => 'PREROUTING',
        destination => $source_ip6,
        proto       => $proto,
        dport       => $port,
        jump        => 'DNAT',
        todest      => $destination_ip6,
      ;

      "100 ${name} (v6)":
        chain       => 'FORWARD',
        destination => $destination_ip6,
        proto       => $proto,
        dport       => $port,
        action      => accept,
      ;

      "100 ${name} snat (v6)":
        table       => nat,
        chain       => 'POSTROUTING',
        destination => $destination_ip6,
        proto       => $proto,
        sport       => $port,
        jump        => 'SNAT',
        tosource    => $source_ip6,
      ;
    }
  }
}
