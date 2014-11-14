class profile::base::disk::beaglebone {
    portage::package { 'sys-fs/btrfs-progs':
        ensure => installed,
        before => Class['kernel::initrd'],
    }

    dracut::conf { 'devices':
        boot_devices => ['/dev/mmcblk0p2', '/dev/mmcblk0p3'],
    }

    crypt::device { 'keyfile':
        device  => '/dev/mmcblk0p2',
        target  => 'keyfile',
        order   => 1,
    }

    crypt::device { 'rpool-crypt0':
        device  => '/dev/mmcblk0p3',
        target  => 'rpool-crypt0',
        keyfile => '/dev/mapper/keyfile',
        order   => 2,
    }

    file { '/etc/local.d/keyfile.start':
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/profile/base/disk/keyfile.start',
    }

    fstab::fs { 'boot':
        device     => 'LABEL=boot',
        mountpoint => '/boot',
        type       => 'ext2',
        options    => 'noatime',
        dump       => 1,
        pass       => 2,
    }

    fstab::fs { 'swap':
        device     => 'LABEL=swap',
        mountpoint => 'none',
        type       => 'swap',
    }

    fstab::fs { 'root':
        device     => 'LABEL=rpool',
        mountpoint => '/',
        type       => 'btrfs',
        options    => 'noatime,ssd,autodefrag,compress=lzo,space_cache',
    }
}
