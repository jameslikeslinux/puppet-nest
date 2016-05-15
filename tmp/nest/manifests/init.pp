class nest (
  $nullmailer_config,
  $package_server,
  $ssh_private_key,
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
  $scaling_factor   = 1.0,
  $dvorak           = false,
  $monitor_layout   = [],
  $primary_monitor  = undef,
  $video_card       = undef,
) {
  if 'workstation' in $profiles {
    $gentoo_profile = 'default/linux/amd64/13.0/desktop/plasma/systemd'
    $input_devices  = 'libinput'
    $video_cards    = 'i965 intel nvidia r600 radeon'
    $use_defaults   = ['pulseaudio']
  } else {
    $gentoo_profile = 'default/linux/amd64/13.0/systemd'
    $input_devices  = undef
    $video_cards    = undef
    $use_defaults   = []
  }
  
  $use_hiera = hiera_array('nest::use', $use)
  $use_combined = union($use_defaults, $use_hiera).sort

  $dpi = inline_template('<%= (@scaling_factor * 96.0).round %>')
  $scaling_factor_rounded = inline_template('<%= @scaling_factor.round %>')
  $scaling_factor_percent_of_rounded = floor(($dpi / ($scaling_factor_rounded * 96.0)) * 1000) / 1000.0

  $console_font_sizes        = [14, 16, 18, 20, 22, 24, 28, 32]
  $console_font_size_ideal   = 16 * $::nest::scaling_factor
  $console_font_size_smaller = inline_template('<%= @console_font_sizes.reverse.find(16) { |size| size - @console_font_size_ideal.round <= 0 } %>')
  $console_font_size         = $console_font_size_smaller

  $cursor_sizes        = [16, 24, 32, 40, 48]
  $cursor_size_ideal   = 24 * $::nest::scaling_factor
  $cursor_size_smaller = inline_template('<%= @cursor_sizes.reverse.find(24) { |size| size - @cursor_size_ideal.round <= 0 } %>')
  $cursor_size         = inline_template('<%= @cursor_sizes[@cursor_sizes.index(@cursor_size_smaller.to_i) - 1] %>')

  # Include standard profile
  contain '::nest::profile::base'

  # Include additional profiles
  contain prefix($profiles, '::nest::profile::')
}
