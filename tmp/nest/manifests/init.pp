class nest (
  $nullmailer_config,
  $ssh_private_key,
  $ssh_public_key,
  $root_mail_alias,
  $profiles         = [],
  $package_keywords = {},
  $package_use      = {},
  $kernel_config    = {},
  $grub_disks       = [],
  $kernel_cmdline   = '',
  $luks_disks       = {},
  $server           = false,
  $cnames           = {},
  $libvirt          = false,
  $use              = [],
) {
  if 'workstation' in $profiles {
    $gentoo_profile = 'default/linux/amd64/13.0/desktop/plasma/systemd'
    $input_devices  = 'evdev keyboard mouse synaptics'
    $video_cards    = 'intel nvidia radeon'
    $use_defaults   = ['pulseaudio']
  } else {
    $gentoo_profile = 'default/linux/amd64/13.0/systemd'
    $input_devices  = undef
    $video_cards    = undef
    $use_defaults   = []
  }
  
  $use_hiera = hiera_array('nest::use', $use)
  $use_combined = union($use_defaults, $use_hiera).sort

  # Include standard profiles
  contain '::nest::profile::setup'
  contain '::nest::profile::base'

  # Set up the package manager before doing anything else
  Class['::nest::profile::setup'] ->
  Class['::nest::profile::base']

  # Include additional profiles
  $profiles.each |$profile| {
    contain "::nest::profile::${profile}"

    # Additional profiles should assume base setup
    Class['::nest::profile::base'] ->
    Class["::nest::profile::${profile}"]
  }
}
