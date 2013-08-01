class profile::base (
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
        'profile::base::users',
        'profile::base::packages',
    ]: }

    profile::role { $roles: }    
}
