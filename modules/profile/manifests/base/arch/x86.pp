class profile::base::arch::x86 {
    class { 'kernel':
        kernel_name     => 'debian-sources',
        kernel_version  => '3.10.11-1',
        package_version => '3.10.11',
        eselect_name    => 'linux-debian-sources-3.10.11',
        config_source   => 'puppet:///modules/profile/base/arch/x86/config',
    }

    class { '::boot':
        default_entry => 'Funtoo Linux',
        gfxmode       => $profile::base::resolution,
    }

    boot::entry { 'Funtoo Linux':
        kernel  => 'kernel[-v]',
        initrd  => 'initramfs[-v]',
        root    => 'zfs',
        params  => ['elevator=noop', 'quiet', 'splash'],
    }

    class { 'java':
        nsplugin => $is_desktop,
    }
}
