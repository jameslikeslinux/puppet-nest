class profile::base (
    $disk_path,
    $disk_mirror_path = undef,
    $disk_profile     = base,
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
