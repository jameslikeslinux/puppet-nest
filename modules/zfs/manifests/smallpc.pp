class zfs::smallpc {
    File {
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        before => Class['kernel::initrd'],
        notify => Class['kernel::initrd'],
    }

    file { '/etc/modprobe.d/zfs.conf':
        content => "options zfs zfs_arc_max=100663296 zfs_arc_meta_limit=33554432 zfs_dirty_data_sync=8388608 zfs_dirty_data_max=67108864 zfs_delay_scale=5000000 zfs_txg_timeout=10 zfs_prefetch_disable=1 zfs_max_recordsize=131072\n",
    }

    file { '/etc/modprobe.d/spl.conf':
        content => "options spl spl_kmem_cache_slab_limit=0\n",
        ensure => absent,
    }

#    sysctl { 'vm.min_free_kbytes':
#        value => '32768',
#    }
}
