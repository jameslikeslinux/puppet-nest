define kernel::modules::blacklist(
    $module = $name,
) {
    concat::fragment { "blacklist-module-${module}":
        target  => '/etc/modprobe.d/blacklist.conf',
        content => template('kernel/blacklist.conf.erb'),
    }
}
