class zfs::sdcard {
    File {
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        before => Class['kernel::initrd'],
        notify => Class['kernel::initrd'],
    }

    file { '/etc/modprobe.d/zfs.conf':
        content => "options zfs zfs_prefetch_disable=1 zfs_no_write_throttle=1 zfs_txg_synctime_ms=5000 zfs_txg_timeout=30\n",
    }
}
