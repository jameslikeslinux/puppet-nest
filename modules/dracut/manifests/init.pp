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

    $use = $has_crypt ? {
        true    => 'device-mapper',
        default => undef,
    }

    portage::makeconf { 'dracut_modules':
        content => join(sort(flatten($modules)), ' '),
    }

    portage::package { 'sys-kernel/dracut':
        ensure => installed,
        use    => $use,
    }
}
