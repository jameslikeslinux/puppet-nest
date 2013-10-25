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
}
