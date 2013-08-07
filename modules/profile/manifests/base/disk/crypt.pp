class profile::base::disk::crypt inherits profile::base::disk::base {
    Dracut::Conf['devices'] {
        boot_devices => ["/dev/disk/by-path/${disk_path}-part3", "/dev/disk/by-path/${disk_path}-part4"],
    }

    crypt::device { 'keyfile':
        device => "/dev/disk/by-path/${disk_path}-part3",
        target => 'keyfile',
        order  => 1,
    }

    crypt::device { 'rpool-crypt1':
        device  => "/dev/disk/by-path/${disk_path}-part4",
        target  => 'rpool-crypt1',
        keyfile => '/dev/mapper/keyfile',
        order   => 2,
    }
}
