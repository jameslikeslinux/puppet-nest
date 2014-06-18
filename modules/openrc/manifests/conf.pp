define openrc::conf (
    $value,
) {
    include openrc

    concat::fragment { "rc.conf-${name}":
        target  => '/etc/rc.conf',
        content => "${name}=\"${value}\"\n",
    }
}
