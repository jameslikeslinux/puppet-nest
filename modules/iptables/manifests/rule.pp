define iptables::rule (
    $order,
    $rule,
    $l3prot  = [v4, v6],
) {
    if v4 in $l3prot {
        concat::fragment { "iptables-rule-${name}":
            target  => 'iptables-rules',
            content => "${rule}\n",
            order   => $order,
        }
    }

    if v6 in $l3prot {
        concat::fragment { "ip6tables-rule-${name}":
            target  => 'ip6tables-rules',
            content => "${rule}\n",
            order   => $order,
        }
    }
}
