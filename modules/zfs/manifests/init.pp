class zfs {
    portage::package { 'sys-fs/zfs':
        use     => 'dracut',
        ensure  => 'installed',
        require => [Class['kernel'], Class['dracut']],
        before  => Class['kernel::initrd'],
    }

    openrc::service { 'zfs':
        runlevel => 'boot',
        enable   => true,
        require  => Portage::Package['sys-fs/zfs'],
    }
}
