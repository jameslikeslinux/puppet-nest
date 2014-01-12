define kernel::modules (
    $source  = undef,
    $content = undef,
    $order   = '10',
) {
    concat::fragment { "kernel-modules-${name}":
        target  => "/etc/conf.d/modules",
        source  => $source,
        content => $content,
        order   => $order,
    }

    file { '/etc/modprobe.d/blacklist.conf':
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/kernel/blacklist.conf',
    }
}
