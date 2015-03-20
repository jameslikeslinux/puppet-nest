define hostname::host (
    $ip,
) {
    if $osfamily == 'gentoo' {
        include hostname

        # Pad IP with zeros to make it sortable
        # XXX: This only works with IPv4!  Also, there is no error checking.
        $sortable_ip = inline_template('<%= "%03d.%03d.%03d.%03d" % @ip.split(".") %>')

        concat::fragment { "hostname-alias-${sortable_ip}-${name}":
            content => "aliases+=\"${ip}\t${name}\n\"\n",
            target  => '/etc/conf.d/hostname',
        }

        host { $name:
            ip      => $ip,
            require => Class['hostname'],
        }
    } else {
        host { $name:
            ip => $ip,
        }
    }
}
