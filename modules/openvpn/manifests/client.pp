class openvpn::client (
    $server,
    $ca_cert,
    $client_cert,
    $client_key,
) {
    class { 'openvpn': }

    openvpn::config { '/etc/openvpn/openvpn.conf':
        server    => $server,
        ca_file   => $ca_cert,
        cert_file => $client_cert,
        key_file  => $client_key,
        require   => Class['openvpn'],
        notify    => Openrc::Service['openvpn'],
    }

    openrc::service { 'openvpn':
        enable  => true,
        require => File['/etc/openvpn/openvpn.conf'],
    }
}
