class nest::role::vpn_server {
    class { 'openvpn::server':
        group       => 'puppet',    # we need permission to read Puppet SSL certs
        ca_cert     => "${settings::ssldir}/certs/ca.pem",
        server_cert => "${settings::ssldir}/certs/${hostname}.pem",
        server_key  => "${settings::ssldir}/private_keys/${hostname}.pem",
        crl         => "${settings::ssldir}/ca/ca_crl.pem",
        network     => '172.22.2.0',
        netmask     => '255.255.255.0',
        require     => Class['nest::role::puppet_master'],
    }

    iptables::accept { 'openvpn':
        port     => 1194,
        protocol => udp
    }
}
