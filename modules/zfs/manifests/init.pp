class zfs {
    if $architecture =~ /arm/ {
        package_keywords { [
            'sys-kernel/spl',
            'sys-fs/zfs-kmod',
            'sys-fs/zfs',
        ]:
            keywords => '**',
            target   => 'zfs',
            version  => '=9999',
            ensure   => 'present',
            before   => Portage::Package['sys-fs/zfs'],
        }
    }

    portage::package { 'sys-fs/zfs':
        use     => 'dracut',
        ensure  => installed,
        require => [Class['kernel'], Class['dracut']],
        before  => Class['kernel::initrd'],
    }

    openrc::service { 'zfs':
        runlevel => 'boot',
        enable   => true,
        require  => Portage::Package['sys-fs/zfs'],
    }

    #
    # During initail installation, inside the chroot, /etc/mtab doesn't
    # exist, which causes zfs dataset creation to fail
    #
    file { '/etc/mtab':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => '/proc/mounts',
        replace => false,
        links   => follow,
    }

    file { '/etc/modprobe.d/spl.conf':
        ensure => absent,
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        content => "options spl spl_kmem_cache_expire=2\n",
        before => Class['kernel::initrd'],
        notify => Class['kernel::initrd'],
    }
}
