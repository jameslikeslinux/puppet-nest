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

    $use = [
        'optimization',

        $has_crypt ? {
            true    => 'device-mapper',
            default => [],
        },
    ]

    portage::makeconf { 'dracut_modules':
        content => join(sort($modules), ' '),
    }

    portage::package { 'sys-kernel/dracut':
        ensure => installed,
        use    => flatten($use),
    }
}
