class profile::base::boot {
    $is_desktop = desktop in $profile::base::roles

    $dracut_modules = [
        $is_desktop ? {
            true    => 'plymouth',
            default => [], 
        },

        $profile::base::boot_disk_mirror ? {
            undef   => [],
            default => ['mdraid'],
        },

        $profile::base::boot_decrypt ? {
            undef   => [],
            default => ['crypt'],
        },
    ]

    class { 'dracut':
        modules => sort(flatten($dracut_modules)),
    }
}
