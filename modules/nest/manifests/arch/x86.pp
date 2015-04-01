class nest::arch::x86 inherits nest::arch::base {
    class { 'kernel':
        kernel_name     => 'debian-sources',
        kernel_version  => '3.16.2-3',
        package_version => '3.16.2',
        eselect_name    => 'linux-debian-sources-3.16.2',
        config_source   => 'puppet:///modules/nest/arch/x86/config',
        distcc          => $::nest::distcc,
    }

    class { '::boot':
        default_entry => 'Funtoo Linux',
        gfxmode       => $nest::resolution,
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
