node 'rpi2' {
    class { 'profile::base':
        arch             => raspberrypi,
        disk_profile     => raspberrypi,
        distcc           => true,
        roles            => [
            package_server,
            web_server,
        ],
    }
}

@host { 'rpi2':
    ip => '172.22.2.6',
}
