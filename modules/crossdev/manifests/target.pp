define crossdev::target (
    $target = $name,
) {
    include crossdev

    # Funtoo has very limited support for Crossdev
    # See: https://bugs.funtoo.org/browse/FL-652
    #      https://bugs.funtoo.org/browse/FL-821
    exec { "/usr/bin/crossdev --stable --gcc 4.8.3-r1 --target ${target}":
        timeout => 0,
        creates => "/usr/bin/${target}-gcc",
        require => Class['crossdev'],
    }
}
