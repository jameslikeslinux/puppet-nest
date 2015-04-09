class boot (
    $default_entry,
    $gfxmode = undef,
) {
    portage::package { 'sys-boot/boot-update':
        ensure  => installed,
        require => Class['grub'],
    }

    concat { 'boot-conf':
        path    => '/etc/boot.conf',
        require => Portage::Package['sys-boot/boot-update'],
        notify  => Exec['boot-update'],
    }

    concat::fragment { 'boot-conf-header':
        target  => 'boot-conf',
        content => template('boot/header.erb'),
        order   => '00',
    }

    exec { 'boot-update':
        command     => '/sbin/boot-update',
        refreshonly => true,
        subscribe   => [Class['kernel'], Class['kernel::initrd']],
    }
}
