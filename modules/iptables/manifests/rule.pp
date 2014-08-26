define iptables::rule (
    $order,
    $rule,
    $l3prot  = [v4, v6],
) {
    $content = "${rule} -m comment --comment \"${name}\"\n"

    if v4 in $l3prot {
        concat::fragment { "iptables-rule-${name}":
            target  => 'iptables-rules',
            content => $content,
            order   => $order,
        }
    }

    if v6 in $l3prot {
        concat::fragment { "ip6tables-rule-${name}":
            target  => 'ip6tables-rules',
            content => $content,
            order   => $order,
        }
    }
}
