class nest (
  $nestfs_hostname,
  $openvpn_hostname,

  $nullmailer_config,
  $root_mail_alias,
  $ssh_private_key,
  $pw_hash,

  $cnames                  = {},
  $distcc_hosts            = {},
  $kernel_config           = {},
  $kernel_cmdline          = [],

  $dvorak                  = false,
  $swap_alt_win            = false,
  $monitor_layout          = [],
  $mouse                   = undef,
  $primary_monitor         = undef,
  $processorcount          = $::processorcount,
  $gui_scaling_factor      = 1.0,
  $text_scaling_factor     = 1.0,
  $touchpad_acceleration   = 0.0,
  $trackpoint_acceleration = 0.0,
  $barrier_config          = undef,
  $video_card              = undef,

  $cflags                  = $::portage_cflags,
  $cpu_flags_x86           = $::portage_cpu_flags_x86,
  $package_env             = {},
  $package_keywords        = {},
  $package_mask            = {},
  $package_use             = {},
  $use                     = [],

  $cups_servers            = [],
  $distcc_server           = false,
  $fileserver              = false,
  $libvirt                 = false,
  $openvpn_server          = false,
  Array[Stdlib::Fqdn] $nist_time_servers = [],

  Optional[Pattern[/(\d+(-\d+)?)(,\d+(-\d+)?)*/]] $isolcpus = undef,

  Hash $hosts              = {},

  Enum['grub', 'systemd'] $bootloader = grub,
  Boolean                 $public_ssh = false,
) {
  if $facts['osfamily'] == 'Gentoo' {
    if $facts['architecture'] == 'amd64' and $::role == 'server' {
      $gentoo_profile = 'default/linux/amd64/17.1/systemd'
      $input_devices  = undef
      $video_cards    = undef
      $use_defaults   = ['X']
    } elsif $facts['architecture'] == 'amd64' and $::role == 'workstation' {
      $gentoo_profile = 'default/linux/amd64/17.1/desktop/plasma/systemd'
      $input_devices  = 'libinput'
      $video_cards    = 'amdgpu i965 intel nvidia radeonsi'
      $use_defaults   = ['pulseaudio', 'vaapi', 'vdpau', 'wayland']
    } elsif $facts['architecture'] == 'aarch64' and $::role == 'server' {
      $gentoo_profile = 'default/linux/arm64/17.0/systemd'
      $input_devices  = undef
      $video_cards    = undef
      $use_defaults   = ['X']
    } elsif $facts['architecture'] == 'aarch64' and $::role == 'workstation' {
      $gentoo_profile = 'default/linux/arm64/17.0/desktop/plasma/systemd'
      $input_devices  = 'libinput'
      $video_cards    = ['panfrost', 'v3d', 'vc4']
      $use_defaults   = ['pulseaudio', 'vaapi', 'wayland']
    } elsif $facts['architecture'] == 'armv7l' and $::platform == 'beagleboneblack' and $::role == 'server' {
      $gentoo_profile = 'default/linux/arm/17.0/armv7a/systemd'
      $input_devices  = undef
      $video_cards    = undef
      $use_defaults   = ['X']
    } else {
      fail("Unsupported configuration: ${facts['architecture']}-${::platform}-${::role}")
    }

    $kernel_config_hiera = hiera_hash('nest::kernel_config', $kernel_config)
    $kernel_cmdline_hiera = hiera_array('nest::kernel_cmdline', $kernel_cmdline)
    $cups_servers_hiera = hiera_array('nest::cups_servers', $cups_servers)
    $package_env_hiera = hiera_hash('nest::package_env', $package_env)
    $package_keywords_hiera = hiera_hash('nest::package_keywords', $package_keywords)
    $package_mask_hiera = hiera_hash('nest::package_mask', $package_mask)
    $package_use_hiera = hiera_hash('nest::package_use', $package_use)
    $use_hiera = hiera_array('nest::use', $use)
    $use_combined = union($use_defaults, $use_hiera).sort
  }

  $dpi = 0 + inline_template('<%= (@text_scaling_factor * 96.0).round %>')
  $gui_scaling_factor_rounded = 0 + inline_template('<%= @gui_scaling_factor.round %>')
  $text_scaling_factor_percent_of_gui = 0.0 + inline_template('<%= (@dpi / (@gui_scaling_factor * 96.0)).round(3) %>')
  $text_scaling_factor_percent_of_rounded_gui = 0.0 + inline_template('<%= (@dpi / (@gui_scaling_factor_rounded * 96.0)).round(3) %>')

  $console_font_sizes        = [16, 18, 20, 22, 24, 28, 32]
  $console_font_size_ideal   = 16 * $::nest::text_scaling_factor
  $console_font_size_smaller = inline_template('<%= @console_font_sizes.reverse.find(16) { |size| size - @console_font_size_ideal <= 0 } %>')
  $console_font_size         = $console_font_size_smaller

  $cursor_sizes        = [24, 32, 36, 40, 48, 64, 96]
  $cursor_size_ideal   = 24 * $::nest::gui_scaling_factor
  $cursor_size_smaller = inline_template('<%= @cursor_sizes.reverse.find(24) { |size| size - @cursor_size_ideal <= 0 } %>')
  $cursor_size         = $cursor_size_smaller

  if $facts['kernel'] == 'Linux' {
    if $isolcpus {
      $isolcpus_expanded = $isolcpus.split(',').map |$cpuset| {
        if $cpuset =~ /-/ {
          $cpuset_split = $cpuset.split('-')
          range($cpuset_split[0], $cpuset_split[1])
        } else {
          0 + $cpuset
        }
      }.flatten
    } else {
      $isolcpus_expanded = []
    }

    $availcpus_expanded = range(0, $facts['processors']['count'] - 1) - $isolcpus_expanded
  }

  # Include standard base configuration
  contain 'nest::base'

  # Apply role-specific configuration
  contain "nest::role::${::role}"

  create_resources(host, $hosts)
}
