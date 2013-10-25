class profile::base::disk::crypt inherits profile::base::disk::base {
    dracut::conf { 'devices':
        boot_devices => ["/dev/disk/by-id/${disk_id}-part3", "/dev/disk/by-id/${disk_id}-part4"],
    }

    crypt::device { 'keyfile':
        device => "/dev/disk/by-id/${disk_id}-part3",
        target => 'keyfile',
        order  => 1,
    }

    crypt::device { 'rpool-crypt0':
        device  => "/dev/disk/by-id/${disk_id}-part4",
        target  => 'rpool-crypt0',
        keyfile => '/dev/mapper/keyfile',
        order   => 2,
    }
}
