class openvpn::server (
    $ca_cert,
    $server_cert,
    $server_key,
    $crl,
    $network,
    $netmask,
    $group = undef,
) {
    class { 'openvpn': }

    exec { 'create-dh-parameters':
        command => '/usr/bin/openssl dhparam -out /etc/openvpn/dh4096.pem 4096',
        creates => '/etc/openvpn/dh4096.pem',
        timeout => 0,
        require => Class['openvpn'],
    }

    if $group {
        user { 'openvpn':
            groups  => $group,
            require => Class['openvpn'],
            before  => File['/etc/openvpn/openvpn.conf'],
        }
    }

    file { '/etc/openvpn/openvpn.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('openvpn/server.conf.erb'),
        require => Class['openvpn'],
        notify  => Openrc::Service['openvpn'],
    }

    openrc::service { 'openvpn':
        enable  => true,
        require => [
            Exec['create-dh-parameters'],
            File['/etc/openvpn/openvpn.conf'],
        ],
    }
}
