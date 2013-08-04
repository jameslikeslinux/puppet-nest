class profile::base::networking {
    #
    # Uses DHCPCD to manage network interface (unless I'm a desktop)
    #
    unless desktop in $profile::base::roles {
        openrc::service { 'dhcpcd':
            enable => true,
        }
    }


    #
    # Is a VPN client (if it's not also a server)
    #
    unless vpn_server in $profile::base::roles {
        class { 'openvpn::client':
            server      => 'vpn.thestaticvoid.com',
            ca_cert     => '/etc/puppet/ssl/certs/ca.pem',
            client_cert => "/etc/puppet/ssl/certs/${hostname}.pem",
            client_key  => "/etc/puppet/ssl/private_keys/${hostname}.pem",
        }
    }


    #
    # Has a hostname
    #
    class { 'hostname':
        hostname => $hostname,
    }


    #
    # and knows about everyone else's...
    #
    Host <| title != $hostname |>


    #
    # Is firewalled.
    #
    class { 'iptables': }

    iptables::accept { 'vpn':
        device => 'tap0',
    }
}
