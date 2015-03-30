class profile::base (
    $arch             = x86,
    $remote_backup    = false,
    $boot_disk        = undef,
    $boot_decrypt     = undef,
    $boot_options     = [],
    $distcc           = false,
    $keymap           = 'dvorak',
    $timezone         = 'America/New_York',
    $resolution       = undef,
    $dpi              = undef,
    $lcd              = true,
    $package_server   = undef,
    $wan              = false,
    $video_cards      = [],
    $video_options    = {},
    $roles            = [],
) {
    #
    # Include profile components.
    #
    class { [
        "profile::base::arch::${arch}",
        'profile::base::boot',
        'profile::base::disk',
        'profile::base::environment',
        'profile::base::networking',
        'profile::base::packages',
        'profile::base::users',
    ]: }

    profile::role { $roles: }

    profile::role { 'ssh_server': }
}
