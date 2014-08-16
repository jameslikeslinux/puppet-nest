class profile::base::disk::zfs {
    class { '::zfs': }

    if $::profile::base::remote_backup == true {
        class { '::zfs::backup':
            remote_host    => 'hawk',
            remote_dataset => "nest/backup/nodes/${clientcert}",
        } 
    } else {
        class { '::zfs::backup': }
    }
}
