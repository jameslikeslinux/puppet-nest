class openrc {
    concat { '/etc/rc.conf': }

    concat::fragment { 'rc.conf-header':
        target => '/etc/rc.conf',
        order  => '00',
        source => 'puppet:///modules/openrc/rc.conf',
    }
}
