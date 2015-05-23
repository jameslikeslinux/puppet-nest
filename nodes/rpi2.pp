node 'rpi2' {
    class { 'nest':
        arch             => raspberrypi,
        disk_profile     => raspberrypi,
        distcc           => true,
        roles            => [
            package_server,
            web_server,
        ],
    }
}

@openvpn::host { 'rpi2':
    ip => '172.22.2.6',
}
