class dracut (
    $modules = [],
) {
    if crypt in $modules {
        $has_crypt = true

        portage::package { 'sys-fs/lvm2':
            use    => 'udev',
            ensure => installed,
            before => Class['kernel::initrd'],
        }
    }

    if plymouth in $modules {
        portage::package { 'sys-boot/plymouth':
            ensure => installed,
            before => Class['kernel::initrd'],
        }
    }

    $use = [
        'optimization',

        $has_crypt ? {
            true    => 'device-mapper',
            default => [],
        },
    ]

    portage::makeconf { 'dracut_modules':
        content => join(sort($modules), ' '),
        notify  => Portage::Package['sys-kernel/dracut'],
    }

    portage::package { 'sys-kernel/dracut':
        ensure => installed,
        use    => flatten($use),
    }
}
