define boot::entry (
    $kernel,
    $initrd,
    $root,
    $params = [],
) {
    concat::fragment { "boot-conf-${name}":
        target  => 'boot-conf',
        content => template('boot/entry.erb'),
    }
}
