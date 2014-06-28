class transmission (
    $port,
    $user  = 'transmission',
    $group = 'transmission',
) {
    portage::package { 'net-p2p/transmission':
        ensure => installed,
    }

    file { [
        '/var/lib/transmission',
        '/var/log/transmission',
    ]:
        owner   => $user,
        group   => $group,
        recurse => true,
        links   => follow,
        require => Portage::Package['net-p2p/transmission'],
    }

    file { '/etc/conf.d/transmission-daemon':
        owner   => root,
        group   => root,
        content => template('transmission/transmission-daemon.confd.erb'),
        require => Portage::Package['net-p2p/transmission'],
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
