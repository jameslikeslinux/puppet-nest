class profile::base::disk::cryptnew inherits profile::base::disk::crypt {
    Dracut::Conf['devices'] {
        boot_devices +> "${disk_id}-part5",
    }

    Crypt::Device['rpool-crypt0'] {
        device => "${disk_id}-part5",
    }

    crypt::device { 'swap':
        device  => "${disk_id}-part4",
        target  => 'swap',
        keyfile => '/dev/mapper/keyfile',
        order   => 2,
    }

    Fstab::Fs['swap'] {
        device => '/dev/mapper/swap',
    }
}
