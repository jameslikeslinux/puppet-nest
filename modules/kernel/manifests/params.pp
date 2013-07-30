class kernel::params {
    $kernel_name     = 'debian-sources'
    $kernel_version  = '3.2.41-2'
    $package_version = '3.2.41'
    $eselect_name    = "linux-${kernel_name}-${package_version}"
}
