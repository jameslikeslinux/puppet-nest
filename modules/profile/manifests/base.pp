class profile::base (
    $timezone           = 'America/New_York',
    $disk_profile       = base,
    $console_resolution = undef,
    $package_server     = undef,
    $video_cards        = [],
    $roles              = [],
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
}
