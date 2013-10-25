class profile::base::disk::cryptmirror inherits profile::base::disk::crypt {
    class { 'mdraid':
        mailaddr => 'root',
    }

    Fstab::Fs['boot'] {
        device => '/dev/md0',
    }

    Dracut::Conf['devices'] {
        boot_devices => ['/dev/md1', "/dev/disk/by-id/${disk_id}-part4", "/dev/disk/by-id/${disk_mirror_id}-part4"],
    }

    Crypt::Device['keyfile'] {
        device => '/dev/md1',
    }

    crypt::device { 'rpool-crypt1':
        device  => "/dev/disk/by-id/${disk_mirror_id}-part4",
        target  => 'rpool-crypt1',
        keyfile => '/dev/mapper/keyfile',
        order   => 3,
    }

    grub::install { "/dev/disk/by-id/${disk_mirror_id}": }
}
