class profile::base::boot {
    class { 'kernel':
        kernel_name     => 'debian-sources',
        kernel_version  => '3.2.41-2',
        package_version => '3.2.41',
        eselect_name    => 'linux-debian-sources-3.2.41',
    }

    $dracut_modules = [
        'plymouth',

        $profile::base::disk_profile ? {
            cryptmirror => 'crypt',
            crypt       => 'crypt',
            default     => '',
        },

        $profile::base::disk_profile ? {
            cryptmirror => 'mdraid',
            default     => '',
        },
    ]

    class { 'dracut':
        modules => $dracut_modules,
    }

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
