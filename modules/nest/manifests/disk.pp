class nest::disk {
    class { '::zfs':
      git => $architecture ? {
        /arm/   => true,
        default => true,
      }
    }

    if $::nest::remote_backup == true {
        class { '::zfs::backup':
            remote_host => 'hawk',
            remote_dataset => "nest/backup/nodes/${clientcert}",
        }
    } else {
        class { '::zfs::backup': }
    }

    if $virtual == 'physical' and $architecture !~ /arm/ {
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

    file { '/hugetlbfs':
        ensure => $nest::hugepages ? {
            undef   => absent,
            default => directory,
        },
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
    }

    fstab::fs { 'hugetlbfs':
        ensure     => $nest::hugepages ? {
            undef   => absent,
            default => present,
        },
        device     => 'hugetlbfs',
        mountpoint => '/hugetlbfs',
        type       => 'hugetlbfs',
        require    => File['/hugetlbfs'],
    }
}
