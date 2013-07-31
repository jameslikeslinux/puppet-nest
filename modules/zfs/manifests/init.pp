class zfs {
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
    exec { '/bin/cp /proc/mounts /etc/mtab':
        creates => '/etc/mtab',
    }

    # XXX What about /etc/hostid?
}
