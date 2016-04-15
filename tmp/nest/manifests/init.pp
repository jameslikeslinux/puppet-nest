class nest (
  $nullmailer_config,
  $ssh_private_key,
  $ssh_public_key,
  $root_mail_alias,
  $profiles = [],
  $package_keywords = {},
  $package_use = {},
  $kernel_config = {},
  $grub_disks = [],
  $kernel_cmdline = '',
  $luks_disks = {},
  $server = false,
  $cnames = {},
) {
  $gentoo_profile = ('workstation' in $profiles) ? {
    true    => 'default/linux/amd64/13.0/desktop/plasma/systemd',
    default => 'default/linux/amd64/13.0/systemd',
  }

  # XXX: Make more generic
  $use = ('workstation' in $profiles) ? {
    true    => ['pulseaudio'],
    default => undef,
  }

  contain '::nest::profile::setup'
  contain '::nest::profile::base'

  Class['::nest::profile::setup'] -> Class['::nest::profile::base']
}
