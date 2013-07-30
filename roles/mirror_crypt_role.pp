class mirror_crypt_role inherits crypt_role {
    Fstab::Fs['boot'] {
        device => '/dev/md0',
    }

    Dracut::Conf['devices'] {
        boot_devices => ['/dev/md1', '/dev/sda4', '/dev/sdb4'],
    }

    Crypt::Device['keyfile'] {
        device => '/dev/md1',
    }

    crypt::device { '/dev/sdb4':
        target  => 'sdb4_crypt',
        keyfile => '/dev/mapper/keyfile',
        order   => 3,
    }

    grub::install { '/dev/sdb': }
}
