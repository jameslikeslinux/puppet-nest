define openvpn::host (
    $ip,
) {
    host { $name:
        ensure => absent,
    }

    host { "${name}.vpn":
        ip           => $ip,
        host_aliases => $name,
    } 
}
