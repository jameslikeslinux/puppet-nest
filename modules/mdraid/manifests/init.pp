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
        warn   => true,
        notify => Class['kernel::initrd'],
    }

    concat::fragment { 'mdadm-conf-scan':
        target  => 'mdadm-conf',
        source  => '/etc/mdadm.conf.scan',
        require => Exec['mdadm-scan'],
    }

    if $mailaddr {
        concat::fragment { 'mdadm-conf-mailaddr':
            target  => 'mdadm-conf',
            content => "MAILADDR $mailaddr\n",
            order   => '09',
        }
    }

    openrc::service { 'mdadm':
        enable  => true,
        require => Concat['mdadm-conf'],
    }
}
