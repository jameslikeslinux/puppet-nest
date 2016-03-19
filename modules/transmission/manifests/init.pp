class transmission (
    $port,
    $use = undef,
) {
    portage::package { 'net-p2p/transmission':
        ensure => installed,
        use    => $use,
    }

    openrc::service { 'transmission-daemon':
        enable  => true,
        require => Portage::Package['net-p2p/transmission'],
    }

    iptables::accept { 'transmission':
        port     => $port,
        protocol => tcp,
    }

    # Since µTP is enabled by default, transmission needs large kernel
    # buffers for the UDP socket.
    sysctl { 'net.core.rmem_max':
        value => '4194304',
    }
    sysctl { 'net.core.wmem_max':
        value => '1048576',
    }
}
