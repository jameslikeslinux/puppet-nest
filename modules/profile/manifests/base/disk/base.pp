class profile::base::disk::base {
    $disk_path        = $profile::base::disk_path
    $disk_mirror_path = $profile::base::disk_mirror_path

    class { 'zfs': }

    fstab::fs { 'boot':
        device     => "/dev/disk/by-path/${disk_path}-part1",
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
        boot_devices => ["/dev/disk/by-path/${disk_path}-part3"],
    }

    grub::install { "/dev/disk/by-path/${disk_path}": }
}
