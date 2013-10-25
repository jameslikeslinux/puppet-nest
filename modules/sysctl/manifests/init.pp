class sysctl {
    concat { '/etc/sysctl.d/local.conf':
        notify => Openrc::Service['sysctl'],
    }

    concat::fragment { 'sysctl-head':
        target => '/etc/sysctl.d/local.conf',
        order  => '00',
        source => 'puppet:///modules/sysctl/sysctl.conf',
    }

    openrc::service { 'sysctl':
        runlevel => 'boot',
        enable   => true,
    }
}
