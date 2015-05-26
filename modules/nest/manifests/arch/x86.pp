class nest::arch::x86 inherits nest::arch::base {
    class { 'kernel':
        kernel_name     => 'debian-sources',
        kernel_version  => '3.19.3-1~exp1',
        package_version => '3.19.3',
        package_use     => '-binary',
        eselect_name    => 'linux-debian-sources-3.19.3',
        config_source   => 'puppet:///modules/nest/arch/x86/config',
        distcc          => $::nest::distcc,
    }

    class { '::boot':
        default_entry  => 'Funtoo Linux',
        serial_console => $nest::serial_console,
        gfxmode        => $nest::resolution,
    }

    grub::install { $nest::boot_disk: }

    boot::entry { 'Funtoo Linux':
        kernel  => 'kernel[-v]',
        initrd  => 'initramfs[-v]',
        root    => 'zfs',
        params  => flatten([$boot_params, 'quiet', 'splash']),
    }

    class { 'java':
        nsplugin => $is_desktop,
    }

    class { 'erlang':
        graphical => $is_desktop,
    }
}
