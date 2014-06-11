class profile::base::disk::cryptnew inherits profile::base::disk::crypt {
    Dracut::Conf['devices'] {
        boot_devices +> "${disk_id}5",
    }

    Crypt::Device['rpool-crypt0'] {
        device => "${disk_id}5",
    }

    crypt::device { 'swap':
        device  => "${disk_id}4",
        target  => 'swap',
        keyfile => '/dev/mapper/keyfile',
        order   => 2,
    }

    Fstab::Fs['swap'] {
        device => '/dev/mapper/swap',
    }
}
