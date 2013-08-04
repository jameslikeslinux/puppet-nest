define iptables::accept (
    $device   = undef,
    $port     = undef,
    $protocol = undef,
    $l3prot   = [v4, v6],
) {
    # XXX All of this logic could and probably should be moved to a template

    if $protocol == both {
        iptables::accept { "${name}-tcp":
            device   => $device,
            port     => $port,
            protocol => tcp,
            l3prot   => $l3prot
        }

        iptables::accept { "${name}-udp":
            device   => $device,
            port     => $port,
            protocol => udp,
            l3prot   => $l3prot
        }
    } elsif $device and !$port and !$protocol {
        iptables::rule { "accept-${device}":
            rule   => "-A INPUT -i ${device} -j ACCEPT",
            order  => '02',
            l3prot => $l3prot,
        }
    } else {
        $padded_port = inline_template('<%= "%05d" % @port %>')

        $rule = $protocol ? {
            icmp   => "-p icmp --icmp-type ${port}",
            icmpv6 => "-p icmpv6 --icmpv6-type ${port}",
            tcp    => "-p tcp --dport ${port}",
            udp    => "-p udp --dport ${port}",
        }

        $input = $device ? {
            undef   => '',
            default => '-i ${device} ',
        }

        iptables::rule { "accept-${padded_port}-${protocol}":
            rule   => "-A INPUT ${input}${rule} -m conntrack --ctstate NEW -j ACCEPT",
            order  => "20",
            l3prot => $l3prot,
        }
    }
}
