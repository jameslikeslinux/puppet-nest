class profile::base::boot {
    $is_desktop = desktop in $profile::base::roles

    $dracut_modules = [
        $is_desktop ? {
            true    => 'plymouth',
            default => [], 
        },

        $profile::base::disk_profile ? {
            beaglebone  => ['btrfs', 'crypt'],
            cryptmirror => ['crypt', 'mdraid'],
            crypt       => 'crypt',
            default     => [],
        },
    ]

    class { 'dracut':
        modules => flatten($dracut_modules),
    }
}
