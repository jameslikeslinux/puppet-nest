class profile::base::disk::base {
    class { 'zfs': }

    fstab::fs { 'boot':
        device     => '/dev/sda1',
        mountpoint => '/boot',
        type       => 'ext2',
        options    => 'noatime',
        dump       => 1,
        pass       => 2
    }

    fstab::fs { 'swap':
        device     => '/dev/zvol/rpool/swap',
        mountpoint => 'none',
        type       => 'swap',
        options    => 'sw',
    }

    dracut::conf { 'devices':
        boot_devices => ['/dev/sda3'],
    }

    grub::install { '/dev/sda': }
}
