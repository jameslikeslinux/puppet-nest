class nest (
  $ssh_private_key,
  $ssh_public_key,
  $profiles = [],
  $package_keywords = {},
  $package_use = {},
  $kernel_config = {},
  $grub_disks = [],
  $kernel_cmdline = '',
  $luks_disks = {},
) {
  $gentoo_profile = ('workstation' in $profiles) ? {
    true    => 'default/linux/amd64/13.0/desktop/plasma/systemd',
    default => 'default/linux/amd64/13.0/systemd',
  }

  contain '::nest::profile::setup'
  contain '::nest::profile::base'

  Class['::nest::profile::setup'] -> Class['::nest::profile::base']
}
