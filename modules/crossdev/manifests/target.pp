define crossdev::target (
    $target = $name,
) {
    include crossdev

    # GCC 4.6.4 doesn't support crossdev on Funtoo
    # See: http://bugs.funtoo.org/browse/FL-652
    exec { "/usr/bin/crossdev --stable --gcc 4.6.3 --target ${target}":
        timeout => 0,
        creates => "/usr/bin/${target}-gcc",
        require => Class['crossdev'],
    }
}
