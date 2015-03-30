class crypt {
    #concat { 'crypttab':
    file { 'crypttab':
        ensure => absent,
        path   => '/etc/crypttab',
        notify => Class['kernel::initrd'],
    }

    package_mask { 'dev-libs/libgcrypt':
        version => '>1.5.3',
        ensure  => absent,
        before  => Portage::Package['sys-fs/cryptsetup'],
    }

    portage::package { 'sys-fs/cryptsetup':
        ensure         => installed,
        use            => ['reencrypt', 'udev'],
        unmask_version => '=1.6.4',
    }

    concat { '/etc/conf.d/dmcrypt':
        require => Portage::Package['sys-fs/cryptsetup'],
    }

    concat::fragment { 'dmcrypt-header':
        target  => '/etc/conf.d/dmcrypt',
        content => template('crypt/header.erb'),
        order   => '00',
    }

    concat::fragment { 'dmcrypt-example':
        target  => '/etc/conf.d/dmcrypt',
        content => template('crypt/dmcrypt.confd.erb'),
        order   => '01',
    }
}
