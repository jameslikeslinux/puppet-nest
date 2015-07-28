define crossdev::target (
    $target = $name,
) {
    include crossdev

    exec { "crossdev-${target}":
        command => "/usr/bin/crossdev --stable --target ${target}",
        timeout => 0,
        creates => "/usr/bin/${target}-gcc",
        require => Class['crossdev'],
    }
}
