class fstab {
    concat { 'fstab':
        path   => '/etc/fstab',
        notify => Class['kernel::initrd'],
    }

    concat::fragment { 'fstab-header':
        target  => 'fstab',
        content => template('fstab/header.erb'),
        order   => '00',
    }

}
