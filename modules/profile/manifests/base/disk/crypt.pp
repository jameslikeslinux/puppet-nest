class profile::base::disk::crypt inherits profile::base::disk::base {
    Dracut::Conf['devices'] {
        boot_devices => ['/dev/sda3', '/dev/sda4'],
    }

    crypt::device { 'keyfile':
        device => '/dev/sda3',
        target => 'keyfile',
        order  => 1,
    }

    crypt::device { 'rpool_vdev':
        device  => '/dev/sda4',
        target  => 'sda4_crypt',
        keyfile => '/dev/mapper/keyfile',
        order   => 2,
    }
}
