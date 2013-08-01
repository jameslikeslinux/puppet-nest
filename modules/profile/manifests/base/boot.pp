class profile::base::boot {
    #
    # Has a kernel.
    #
    class { 'kernel':
        kernel_name     => 'debian-sources',
        kernel_version  => '3.2.41-2',
        package_version => '3.2.41',
        eselect_name    => 'linux-debian-sources-3.2.41',
    }

    #
    # Has a graphical boot.
    #
    class { 'plymouth': }

    class { '::boot':
        default_entry => 'Funtoo Linux',
        gfxmode       => $profile::base::console_resolution,
    }

    boot::entry { 'Funtoo Linux':
        kernel  => 'kernel[-v]',
        initrd  => 'initramfs[-v]',
        root    => 'zfs',
        params  => ['elevator=noop', 'quiet', 'splash'],
    }
}
