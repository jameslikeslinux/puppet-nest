class nest::role::vpn_server {
    class { 'openvpn::server':
        ca_cert     => '/etc/puppet/ssl/certs/ca.pem',
        server_cert => "/etc/puppet/ssl/certs/${hostname}.pem",
        server_key  => "/etc/puppet/ssl/private_keys/${hostname}.pem",
        crl         => '/etc/puppet/ssl/ca/ca_crl.pem',
        network     => '172.22.2.0',
        netmask     => '255.255.255.0',
        require     => Class['nest::role::puppet_master'],
    }

    iptables::accept { 'openvpn':
        port     => 1194,
        protocol => udp
    }
}
