node 'magpi1' {
    class { 'profile::base':
        arch             => raspberrypi,
        disk_profile     => raspberrypi,
        distcc           => true,
        package_server   => 'http://rpi2/packages/',
        roles            => [
            package_server,
            web_server,
        ],
    }
}

@host { 'magpi1':
    ip => '172.22.2.7',
}
