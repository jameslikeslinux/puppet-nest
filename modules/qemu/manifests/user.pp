class qemu::user inherits qemu {
    package_use { [
        'dev-libs/glib',
        'sys-apps/attr',
        'sys-libs/zlib',
    ]:
        use    => 'static-libs',
        before => Portage::Package['app-emulation/qemu'],
    }

    portage::makeconf { 'qemu_user_targets':
        content => 'arm',
    }

    Portage::Package['app-emulation/qemu'] {
        use +> 'static-user',
    }

    file { '/usr/bin/qemu-arm-cortex-a8.c':
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/qemu/qemu-arm-cortex-a8.c',
    }

    exec { 'compile-qemu-arm-cortex-a8':
        command     => '/usr/bin/gcc -static /usr/bin/qemu-arm-cortex-a8.c -O3 -s -o /usr/bin/qemu-arm-cortex-a8',
        refreshonly => true,
        subscribe   => File['/usr/bin/qemu-arm-cortex-a8.c'],
    }

    file { '/etc/init.d/qemu-binfmt':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/qemu/qemu-binfmt.initd',
        require => [
            Portage::Package['app-emulation/qemu'],
            Exec['compile-qemu-arm-cortex-a8'], # (not /strictly/ required)
        ],
    }

    openrc::service { 'qemu-binfmt':
        enable => true,
    }
}
