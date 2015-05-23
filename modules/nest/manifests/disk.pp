class nest::disk {
    class { '::zfs': }

    if $::nest::remote_backup == true {
        class { '::zfs::backup':
            remote_host => 'hawk',
            remote_dataset => "nest/backup/nodes/${clientcert}",
        }
    } else {
        class { '::zfs::backup': }
    }

    if $virtual == 'physical' {
        class { '::smart': }
    }

    if is_array($nest::boot_disk) and size($nest::boot_disk) > 1 {
        class { '::mdraid':
            mailaddr => 'root',
        }
    }

    fstab::fs { 'boot':
        device     => "LABEL=boot",
        mountpoint => '/boot',
        type       => 'ext2',
        options    => 'noatime',
        dump       => 1,
        pass       => 2
    }

    fstab::fs { 'swap':
        device     => 'LABEL=swap',
        mountpoint => 'none',
        type       => 'swap',
        options    => 'discard',
    }
}
