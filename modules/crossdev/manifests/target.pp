define crossdev::target (
    $target = $name,
) {
    include crossdev

    package_mask { "cross-${target}/gcc":
        version => '>4.8.4',
        before  => Exec["crossdev-${target}"],
    }

    exec { "crossdev-${target}":
        command => "/usr/bin/crossdev --stable --target ${target}",
        timeout => 0,
        creates => "/usr/bin/${target}-gcc",
        require => Class['crossdev'],
    }
}
