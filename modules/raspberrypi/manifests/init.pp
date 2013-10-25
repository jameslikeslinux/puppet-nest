class raspberrypi {
    portage::package { [
        'media-libs/raspberrypi-userland',
        'sys-boot/raspberrypi-firmware',
    ]:
        ensure => installed,
    }

    concat { '/boot/config.txt':
        mode    => '0755',
        require => Portage::Package['sys-boot/raspberrypi-firmware'],
    }

    concat::fragment { 'raspberrypy-config-header':
        target => '/boot/config.txt',
        source => 'puppet:///modules/raspberrypi/header',
        order  => '00',
    }
}
