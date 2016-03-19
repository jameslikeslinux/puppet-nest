class zfs (
    $git = false,
) {
    package_keywords { [
        'sys-kernel/spl',
        'sys-fs/zfs-kmod',
        'sys-fs/zfs',
    ]:
        ensure   => $git ? {
            true    => present,
            default => absent,
        },
        keywords => '**',
        target   => 'zfs',
        version  => '=9999',
        before   => Portage::Package['sys-fs/zfs'],
    }

    package_unmask { [
        'sys-kernel/spl',
        'sys-fs/zfs-kmod',
        'sys-fs/zfs',
    ]:
        ensure   => $git ? {
            true    => present,
            default => absent,
        },
        target   => 'zfs',
        version  => '=9999',
        before   => Portage::Package['sys-fs/zfs'],
    }

    portage::package { 'sys-fs/zfs':
        use     => 'dracut',
        ensure  => installed,
        require => [Class['kernel'], Class['dracut']],
        before  => Class['kernel::initrd'],
    }

    openrc::service { 'zfs':
        runlevel => 'boot',
        enable   => false,
        require  => Portage::Package['sys-fs/zfs'],
    }

    openrc::service { 'zfs-import':
        runlevel => 'boot',
        enable   => true,
        require  => Portage::Package['sys-fs/zfs'],
    }

    openrc::service { 'zfs-mount':
        runlevel => 'boot',
        enable   => true,
        require  => Portage::Package['sys-fs/zfs'],
    }

    openrc::service { 'zfs-zed':
        enable   => true,
        require  => Portage::Package['sys-fs/zfs'],
    }

    openrc::service { 'zfs-share':
        enable   => true,
        require  => Portage::Package['sys-fs/zfs'],
    }

    #
    # During initail installation, inside the chroot, /etc/mtab doesn't
    # exist, which causes zfs dataset creation to fail
    #
    file { '/etc/mtab':
        source  => '/proc/mounts',
        replace => false,
        links   => follow,
    }
}
