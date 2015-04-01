class nest::boot {
    $is_desktop = desktop in $nest::roles
    $is_mirrored = is_array($nest::boot_disk) and size($nest::boot_disk) > 1

    $dracut_modules = [
        $is_desktop ? {
            true    => 'plymouth',
            default => [],
        },

        $is_mirrored ? {
            false   => [],
            default => ['mdraid'],
        },

        $nest::boot_decrypt ? {
            undef   => [],
            default => ['crypt'],
        },
    ]

    class { 'dracut':
        modules => sort(flatten($dracut_modules)),
    }
}
