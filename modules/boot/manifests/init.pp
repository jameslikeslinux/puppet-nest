class boot (
    $default_entry,
    $serial_console,
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

    if $gfxmode == native {
        exec { 'grub-set-native-gfxmode':
            command => '/bin/sed -i "/set gfxmode=.*/d" /boot/grub/grub.cfg',
            onlyif  => '/bin/grep "set gfxmode=.*" /boot/grub/grub.cfg',
            require => Exec['boot-update'],
        }
    }

    $enable_serial_console = $serial_console ? {
        undef   => absent,
        default => present,
    }

    file_line { 'grub-configure-serial-device':
        ensure  => $enable_serial_console,
        path    => '/boot/grub/grub.cfg',
        line    => "serial --unit=${serial_console} --speed=115200",
        after   => '^fi$',
        require => Exec['boot-update'],
    }

    file_line { 'grub-enable-serial-output':
        ensure  => $enable_serial_console,
        path    => '/boot/grub/grub.cfg',
        line    => 'terminal_output --append serial',
        after   => '^serial',
        require => File_line['grub-configure-serial-device'],
    }
}
