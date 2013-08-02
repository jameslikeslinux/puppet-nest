class profile::role::vpn_server {
    class { 'openvpn::server':
        ca_cert     => '/etc/puppet/ssl/certs/ca.pem',
        server_cert => "/etc/puppet/ssl/certs/${fqdn}.pem",
        server_key  => "/etc/puppet/ssl/private_keys/${fqdn}.pem",
        network     => '172.22.2.0',
        netmask     => '255.255.255.0',
        require     => Class['profile::role::puppet_master'],
    }
}
