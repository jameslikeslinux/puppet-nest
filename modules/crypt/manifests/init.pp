class crypt {
    concat { 'crypttab':
        path   => '/etc/crypttab',
        notify => Class['kernel::initrd'],
    }

    concat::fragment { 'crypttab-header':
        target  => 'crypttab',
        content => template('crypt/header.erb'),
        order   => '00',
    }
}
