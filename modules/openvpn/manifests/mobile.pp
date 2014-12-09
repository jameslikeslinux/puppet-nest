define openvpn::mobile {
    # This will fail unless you run 'puppet cert generate <name>' first.
    # Yes, this hard-codes paths and server names, but it's only meant
    # for me.

    openvpn::config { "/nest/home/openvpn/${name}.ovpn":
        server    => 'vpn.thestaticvoid.com',
        ca_file   => "${settings::ssldir}/certs/ca.pem",
        cert_file => "${settings::ssldir}/certs/${name}.pem",
        key_file  => "${settings::ssldir}/private_keys/${name}.pem",
        embed     => true,
    }
}
