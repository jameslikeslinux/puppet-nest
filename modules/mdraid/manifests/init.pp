class mdraid (
    $mailaddr = undef,
) {
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
        target => 'mdadm-conf',
        source => 'puppet:///modules/mdraid/header',
    }

    concat::fragment { 'mdadm-conf-scan':
        target  => 'mdadm-conf',
        ensure  => '/etc/mdadm.conf.scan',
        require => Exec['mdadm-scan'],
    }

    if $mailaddr {
        concat::fragment { 'mdadm-conf-mailaddr':
            target  => 'mdadm-conf',
            content => "MAILADDR $mailaddr\n",
        }
    }

    openrc::service { 'mdadm':
        enable  => true,
        require => Concat['mdadm-conf'],
    }
}
