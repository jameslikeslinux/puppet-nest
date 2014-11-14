class zfs::smallpc {
    File {
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        before => Class['kernel::initrd'],
        notify => Class['kernel::initrd'],
    }

    file { '/etc/modprobe.d/zfs.conf':
        content => "options zfs zfs_arc_max=127926272 zfs_dirty_data_max=67108864 zfs_txg_timeout=30 zfs_prefetch_disable=1 zfs_arc_shrink_shift=0\n",
    }

    sysctl { 'vm.min_free_kbytes':
        value => '32768',
    }
}
