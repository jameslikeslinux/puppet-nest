class profile::base::disk::cryptmirror inherits profile::base::disk::crypt {
    class { 'mdraid': }

    Fstab::Fs['boot'] {
        device => '/dev/md0',
    }

    Dracut::Conf['devices'] {
        boot_devices => ['/dev/md1', "/dev/disk/by-path/${disk_path}-part4", "/dev/disk/by-path/${disk_mirror_path}-part4"],
    }

    Crypt::Device['keyfile'] {
        device => '/dev/md1',
    }

    crypt::device { 'rpool-crypt1':
        device  => "/dev/disk/by-path/${disk_mirror_path}-part4",
        target  => 'rpool-crypt1',
        keyfile => '/dev/mapper/keyfile',
        order   => 3,
    }

    grub::install { "/dev/disk/by-path/${disk_mirror_path}": }
}
