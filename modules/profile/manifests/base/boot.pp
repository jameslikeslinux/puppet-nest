class profile::base::boot {
    $is_desktop = desktop in $profile::base::roles

    $dracut_modules = [
        $is_desktop ? {
            true    => 'plymouth',
            default => [], 
        },

        $profile::base::disk_profile ? {
            cryptmirror => 'crypt',
            crypt       => 'crypt',
            default     => [],
        },

        $profile::base::disk_profile ? {
            cryptmirror => 'mdraid',
            default     => [],
        },
    ]

    class { 'dracut':
        modules => flatten($dracut_modules),
    }
}
