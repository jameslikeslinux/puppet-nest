class nest (
  $nullmailer_config,
  $ssh_private_key,
  $root_mail_alias,
  $package_keywords = {},
  $package_use      = {},
  $kernel_config    = {},
  $kernel_cmdline   = '',
  $extra_luks_disks = {},
  $server           = false,
  $cnames           = {},
  $libvirt          = false,
  $use              = [],
  $scaling_factor   = 1.0,
  $dvorak           = false,
  $monitor_layout   = [],
  $primary_monitor  = undef,
  $video_card       = undef,
  $lastfm_pw_hash   = undef,
  $live             = $::nest['live'],
  $vm               = ($::virtual == 'kvm'),
) {
  if $::nest['profile'] == 'workstation' {
    $gentoo_profile = 'default/linux/amd64/13.0/desktop/plasma/systemd'
    $input_devices  = 'libinput'
    $video_cards    = 'i965 intel nvidia r600 radeon'
    $use_defaults   = ['pulseaudio', 'vaapi', 'vdpau']
  } else {
    $gentoo_profile = 'default/linux/amd64/13.0/systemd'
    $input_devices  = undef
    $video_cards    = undef
    $use_defaults   = []
  }
  
  $package_keywords_hiera = hiera_hash('nest::package_keywords', $package_keywords)
  $package_use_hiera = hiera_hash('nest::package_use', $package_use)
  $use_hiera = hiera_array('nest::use', $use)
  $use_combined = union($use_defaults, $use_hiera).sort

  $dpi = inline_template('<%= (@scaling_factor * 96.0).round %>')
  $scaling_factor_rounded = inline_template('<%= @scaling_factor.round %>')
  $scaling_factor_percent_of_rounded = floor(($dpi / ($scaling_factor_rounded * 96.0)) * 1000) / 1000.0

  $console_font_sizes        = [14, 16, 18, 20, 22, 24, 28, 32]
  $console_font_size_ideal   = 16 * $::nest::scaling_factor
  $console_font_size_smaller = inline_template('<%= @console_font_sizes.reverse.find(16) { |size| size - @console_font_size_ideal.round <= 0 } %>')
  $console_font_size         = $console_font_size_smaller

  $cursor_sizes        = [24, 32, 40, 48, 64, 96]
  $cursor_size_ideal   = 24 * $::nest::scaling_factor
  $cursor_size_smaller = inline_template('<%= @cursor_sizes.reverse.find(24) { |size| size - @cursor_size_ideal.round <= 0 } %>')
  $cursor_size         = $cursor_size_smaller

  $luks_disks = $::partitions.reduce({}) |$memo, $value| {
    $partition  = $value[0]
    $attributes = $value[1]
    if $attributes['filesystem'] == 'crypto_LUKS' and "${::trusted['certname']}-" in $attributes['partlabel'] {
      merge($memo, { $attributes['partlabel'] => $attributes['uuid'] })
    } else {
      $memo
    }
  }.merge($extra_luks_disks)

  # Include standard profile
  contain '::nest::profile::base'

  if $::nest['profile'] == 'workstation' {
    contain '::nest::profile::workstation'
  }
}
