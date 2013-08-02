class openvpn::client (
    $server,
    $ca_cert,
    $client_cert,
    $client_key,
) {
    class { 'openvpn': }

    file { '/etc/openvpn/openvpn.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('openvpn/client.conf.erb'),
        require => Class['openvpn'],
        notify  => Openrc::Service['openvpn'],
    }

    openrc::service { 'openvpn':
        enable  => true,
        require => File['/etc/openvpn/openvpn.conf'],
    }
}
