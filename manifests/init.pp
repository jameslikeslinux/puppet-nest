class nest (
  # Required settings
  Stdlib::Host $nestfs_hostname,
  Stdlib::Host $openvpn_hostname,
  String       $pw_hash,
  String       $ssh_private_key,

  # Service discovery configuration
  Hash[Stdlib::Fqdn, Stdlib::Fqdn] $cnames       = {},
  Array[Stdlib::Host]              $cups_servers = [],
  Hash[Stdlib::Host, Integer]      $distcc_hosts = {},
  Hash[Stdlib::Fqdn, Hash]         $hosts        = {},

  # Service toggles
  Boolean $distcc_server  = false,
  Boolean $fileserver     = false,
  Boolean $fscache        = true,
  Boolean $openvpn_server = false,
  Boolean $public_ssh     = false,

  # System settings
  Enum['grub', 'systemd']     $bootloader     = grub,
  Optional[Integer]           $cpus           = undef,
  Boolean                     $isolate_smt    = false,
  Hash[String, Nest::Kconfig] $kernel_config  = {},
  Array[String]               $kernel_cmdline = [],

  # Mail settings
  Optional[String] $gmail_username   = undef,
  Optional[String] $gmail_password   = undef,
  Enum['nullmailer', 'postfix'] $mta = nullmailer,

  # Package resources
  Hash[String, Hash] $package_env      = {},
  Hash[String, Hash] $package_keywords = {},

  # Input settings
  Boolean $dvorak       = false,
  Boolean $swap_alt_win = false,

  # Output settings
  Float            $gui_scaling_factor  = 1.0,
  Float            $text_scaling_factor = 1.0,
  Array[String]    $monitor_layout      = [],
  Optional[String] $primary_monitor     = undef,
) {
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
  contain "nest::role::${facts['profile']['role']}"

  # Let client ask for a tool configuration
  if $facts['build'] in ['buildah', 'pdk', 'qemu', 'r10k'] {
    contain "nest::tool::${facts['build']}"
  }
}
