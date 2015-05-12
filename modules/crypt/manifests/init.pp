class crypt {
    concat { 'crypttab':
        path   => '/etc/crypttab',
        warn   => true,
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
        warn    => true,
        require => Portage::Package['sys-fs/cryptsetup'],
    }

    concat::fragment { 'dmcrypt-example':
        target  => '/etc/conf.d/dmcrypt',
        content => template('crypt/dmcrypt.confd.erb'),
        order   => '01',
    }
}
