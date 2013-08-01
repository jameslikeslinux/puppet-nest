class mdraid {
    portage::package { 'sys-fs/mdadm':
        ensure => 'latest',
    }

    exec { 'mdadm-scan':
        command => '/sbin/mdadm --detail --scan > /etc/mdadm.conf.scan',
        creates => '/etc/mdadm.conf.scan',
        require => Portage::Package['sys-fs/mdadm'],
    }

    concat { 'mdadm-conf':
        path   => '/etc/mdadm.conf',
        notify => Class['kernel::initrd'],
    }

    concat::fragment { 'mdadm-conf-header':
        target  => 'mdadm-conf',
        content => template('mdraid/header.erb'),
    }

    concat::fragment { 'mdadm-conf-scan':
        target  => 'mdadm-conf',
        ensure  => '/etc/mdadm.conf.scan',
        require => Exec['mdadm-scan'],
    }
}
