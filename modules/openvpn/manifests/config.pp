define openvpn::config (
    $server,
    $ca_file,
    $cert_file,
    $key_file,
    $embed  = false,
) {
    if $embed {
        $ca_content   = file($ca_file)
        $cert_content = file($cert_file)
        $key_content  = file($key_file)
    }

    file { $name:
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('openvpn/client.conf.erb'),
    }
}
