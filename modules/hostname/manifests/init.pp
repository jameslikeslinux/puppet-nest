class hostname (
    $hostname,
) {
    concat { '/etc/conf.d/hostname':
        notify => Service['hostname'],
    }

    concat::fragment { 'hostname-head':
        content => template('hostname/confd.erb'),
        target  => '/etc/conf.d/hostname',
        order   => '00',
    }

    service { 'hostname': }
}
