class profile::base::boot {
    $is_desktop = desktop in $profile::base::roles
    $is_mirrored = is_array($profile::base::boot_disk) and size($profile::base::boot_disk) > 1

    $dracut_modules = [
        $is_desktop ? {
            true    => 'plymouth',
            default => [],
        },

        $is_mirrored ? {
            false   => [],
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
