define nest::lib::port_forward (
  Enum['tcp', 'udp']                $proto,
  Stdlib::Port                      $from_port,
  Stdlib::Port                      $to_port,
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

        "100 ${name}: modify dest on incoming packets (${comment})":
          table       => nat,
          chain       => 'PREROUTING',
          destination => $spec['source'],
          proto       => $proto,
          dport       => $from_port,
          jump        => 'DNAT',
          todest      => "${spec['destination']}:${to_port}",
        ;

        "100 ${name}: modify dest on generated packets (${comment})":
          table       => nat,
          chain       => 'OUTPUT',
          destination => $spec['source'],
          proto       => $proto,
          dport       => $from_port,
          jump        => 'DNAT',
          todest      => "${spec['destination']}:${to_port}",
        ;

        "100 ${name}: allow forwarding (${comment})":
          chain       => 'FORWARD',
          destination => $spec['destination'],
          proto       => $proto,
          dport       => $to_port,
          action      => accept,
        ;

        "100 ${name}: allow return packets (${comment})":
          chain   => 'FORWARD',
          source  => $spec['destination'],
          ctstate => ['RELATED', 'ESTABLISHED'],
          action  => accept,
        ;

        "100 ${name}: modify source for return routing (${comment})":
          table       => nat,
          chain       => 'POSTROUTING',
          destination => $spec['destination'],
          proto       => $proto,
          dport       => $to_port,
          jump        => 'MASQUERADE',
        ;
      }
    }
  }
}
