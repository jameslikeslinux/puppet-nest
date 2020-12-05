define nest::lib::port_forward (
  Stdlib::Port                      $port,
  Enum['tcp', 'udp']                $proto,
  Optional[Stdlib::IP::Address::V4] $source_ip4      = undef,
  Optional[Stdlib::IP::Address::V4] $destination_ip4 = undef,
  Optional[Stdlib::IP::Address::V6] $source_ip6      = undef,
  Optional[Stdlib::IP::Address::V6] $destination_ip6 = undef,
) {
  $combined_spec = {
    'v4' => {
      'source'      => $source_ip4,
      'destination' => $destination_ip4,
      'provider'    => iptables,
    },

    'v6' => {
      'source'      => $source_ip6,
      'destination' => $destination_ip6,
      'provider'    => ip6tables,
    },
  }

  $combined_spec.each |$comment, $spec| {
    if $spec['source'] and $spec['destination'] {
      firewall {
        default:
          provider => $spec['provider'],
        ;

        "100 ${name} dnat (${comment})":
          table       => nat,
          chain       => 'PREROUTING',
          destination => $spec['source'],
          proto       => $proto,
          dport       => $port,
          jump        => 'DNAT',
          todest      => $spec['destination'],
        ;

        "100 ${name} (${comment})":
          chain       => 'FORWARD',
          destination => $spec['destination'],
          proto       => $proto,
          dport       => $port,
          action      => accept,
        ;

        "100 ${name} snat (${comment})":
          table       => nat,
          chain       => 'POSTROUTING',
          destination => $spec['destination'],
          proto       => $proto,
          sport       => $port,
          jump        => 'SNAT',
          tosource    => $spec['source'],
        ;
      }
    }
  }
}
