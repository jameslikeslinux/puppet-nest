class crypt_role inherits base_role {
    Dracut::Conf['devices'] {
        boot_devices => ['/dev/sda3', '/dev/sda4'],
    }

    class { 'mdraid': }
    class { 'crypt': }

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

    # XXX: Add service to close keyfile after boot
}
