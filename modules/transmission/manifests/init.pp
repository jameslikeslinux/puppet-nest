class transmission (
    $port,
) {
    portage::package { 'net-p2p/transmission':
        ensure => installed,
    }

    openrc::service { 'transmission-daemon':
        enable  => true,
        require => Portage::Package['net-p2p/transmission'],
    }

    iptables::accept { 'transmission':
        port     => $port,
        protocol => tcp,
    }   
}
