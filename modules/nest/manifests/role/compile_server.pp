class nest::role::compile_server {
    crossdev::target { [
        'armv6j-hardfloat-linux-gnueabi',
        'armv7a-hardfloat-linux-gnueabi',
    ]:
        require => Overlay['local-crossdev'],
    }

    class { 'distcc::server': }
}
