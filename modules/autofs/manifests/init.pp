class autofs {
    portage::package { 'net-fs/autofs':
        ensure => installed,
    }

    concat { '/etc/autofs/auto.master':
        require => Portage::Package['net-fs/autofs'],
        notify  => Openrc::Service['autofs'],
    }

    concat::fragment { 'auto.master-header':
        target => '/etc/autofs/auto.master',
        source => 'puppet:///modules/autofs/auto.master',
        order  => '00',
    }

    openrc::service { 'autofs':
        enable  => true,
        require => Concat['/etc/autofs/auto.master'],
    }
}
