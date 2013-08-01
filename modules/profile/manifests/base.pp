class profile::base (
    $disk_profile       = base,
    $console_resolution = undef,
    $desktop            = false,
    $package_server     = undef,
) {
    class { "profile::base::disk::${disk_profile}": }
    class { 'profile::base::boot': }
    class { 'profile::base::environment': }
    class { 'profile::base::users': }
    class { 'profile::base::packages': }
}
