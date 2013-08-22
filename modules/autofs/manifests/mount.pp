define autofs::mount (
    $map,
    $key,
    $options = undef,
    $location,
) {
    if $map == 'direct' {
        include autofs::direct
    }

    concat::fragment { "${map}-mount-${name}":
        target  => "/etc/autofs/auto.${map}",
        content => template('autofs/map.erb'),
    }
}
