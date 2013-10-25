class profile::base (
    $arch             = x86,
    $disk_id          = undef,
    $disk_mirror_id   = undef,
    $disk_profile     = base,
    $distcc           = false,
    $timezone         = 'America/New_York',
    $resolution       = undef,
    $dpi              = undef,
    $lcd              = true,
    $package_server   = undef,
    $video_cards      = [],
    $roles            = [],
) {
    #
    # Include profile components.
    #
    class { [
        "profile::base::arch::${arch}",
        "profile::base::disk::${disk_profile}",
        'profile::base::boot',
        'profile::base::environment',
        'profile::base::networking',
        'profile::base::packages',
        'profile::base::users',
    ]: }

    profile::role { $roles: }

    profile::role { 'ssh_server': }
}
