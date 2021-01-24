class nest (
  $nestfs_hostname,
  $openvpn_hostname,

  $ssh_private_key,
  $pw_hash,

  $cnames                  = {},
  $distcc_hosts            = {},
  $kernel_config           = {},
  $kernel_cmdline          = [],

  $dvorak                  = false,
  $swap_alt_win            = false,
  $monitor_layout          = [],
  $primary_monitor         = undef,
  $gui_scaling_factor      = 1.0,
  $text_scaling_factor     = 1.0,
  $touchpad_acceleration   = 0.0,
  $trackpoint_acceleration = 0.0,
  $barrier_config          = undef,

  $package_env             = {},
  $package_keywords        = {},

  $cups_servers            = [],
  $distcc_server           = false,
  $fileserver              = false,
  $openvpn_server          = false,
  Array[Stdlib::Fqdn] $nist_time_servers = [],


  Enum['grub', 'systemd']       $bootloader     = grub,
  Optional[Integer]             $cpus           = undef,
  Hash                          $hosts          = {},
  Boolean                       $isolate_smt    = false,
  Boolean                       $public_ssh     = false,

  # Mail settings
  Optional[String]              $gmail_username = undef,
  Optional[String]              $gmail_password = undef,
  Enum['nullmailer', 'postfix'] $mta            = nullmailer,
) {
  if $facts['osfamily'] == 'Gentoo' {
    $kernel_config_hiera = hiera_hash('nest::kernel_config', $kernel_config)
    $kernel_cmdline_hiera = hiera_array('nest::kernel_cmdline', $kernel_cmdline)
    $cups_servers_hiera = hiera_array('nest::cups_servers', $cups_servers)
    $package_env_hiera = hiera_hash('nest::package_env', $package_env)
    $package_keywords_hiera = hiera_hash('nest::package_keywords', $package_keywords)
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

  if $cpus {
    $concurrency = $cpus
  } elsif $isolate_smt {
    $concurrency = $facts['processors']['count'] / 2
  } else {
    $concurrency = $facts['processors']['count']
  }

  # Include standard base configuration
  contain 'nest::base'

  # Apply role-specific configuration
  contain "nest::role::${::role}"

  # Let client ask for a tool configuration
  if $facts['tool'] {
    contain "nest::tool::${tool}"
  }

  create_resources(host, $hosts)
}
