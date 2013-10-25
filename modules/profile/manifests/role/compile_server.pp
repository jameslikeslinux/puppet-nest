class profile::role::compile_server {
    overlay { 'local-crossdev':
        target => '/usr/local/portage-crossdev',
        before => Class['makeconf'],
    }

    crossdev::target { [
        'armv6j-hardfloat-linux-gnueabi',
        'armv7a-hardfloat-linux-gnueabi',
    ]:
        require => Overlay['local-crossdev'],
    }

    class { 'distcc::server': }
}
