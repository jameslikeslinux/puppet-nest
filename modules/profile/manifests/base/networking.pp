class profile::base::networking {
    #
    # Uses DHCPCD to manage network interface (unless I'm a desktop)
    #
#    unless desktop in $profile::base::roles {
#        openrc::service { 'dhcpcd':
#            enable => true,
#        }
#    }


    #
    # Is a VPN client (if it's not also a server)
    #
    unless vpn_server in $profile::base::roles {
        class { 'openvpn::client':
            server      => 'vpn.thestaticvoid.com',
            ca_cert     => '/etc/puppet/ssl/certs/ca.pem',
            client_cert => "/etc/puppet/ssl/certs/${clientcert}.pem",
            client_key  => "/etc/puppet/ssl/private_keys/${clientcert}.pem",
        }
    }


    #
    # Has a hostname
    #
    class { 'hostname':
        hostname => $clientcert,
    }


    #
    # and knows about everyone else's...
    #
    Host <| title != $clientcert |>


    #
    # Is firewalled.
    #
    class { 'iptables': }

    iptables::accept { 'vpn-old':
        device => 'tap0',
    }

    iptables::accept { 'vpn':
        device => 'tun0',
    }


    #
    # Uses NFS
    #
    class { 'nfs': }
    class { 'nfs::idmapd':
        domain => 'thestaticvoid.com',
    }


    unless nest in $profile::base::roles {
        class { 'profile::role::nest_client': }
    }


    portage::package { 'net-misc/iperf':
        ensure    => installed,
        use       => 'threads',
        mask_slot => '3',
    }

    portage::package { 'net-analyzer/traceroute':
        ensure => installed,
    }
}
