class nest (
  # Required settings
  String               $uboot_tag,
  String               $kernel_tag,
  Stdlib::Host         $nestfs_hostname,
  Array[Stdlib::Host]  $openvpn_servers,
  String               $pw_hash,
  Hash[String, String] $ssh_host_keys,
  Hash[String, String] $ssh_private_keys,

  # eyaml keys
  String    $eyaml_public_key,
  Sensitive $eyaml_private_key,

  # Service discovery configuration
  Hash[Stdlib::Fqdn, Stdlib::Fqdn]        $cnames       = {},
  Array[Stdlib::Host]                     $cups_servers = [],
  Hash[Stdlib::Host, Integer]             $distcc_hosts = {},
  Hash[Stdlib::Fqdn, Stdlib::IP::Address] $host_records = {},
  Hash[Stdlib::Fqdn, Hash]                $hosts        = {},

  # Service toggles
  Boolean $distcc_server  = false,
  Boolean $fileserver     = false,
  Boolean $fscache        = true,
  Boolean $openvpn        = false,
  Boolean $puppet         = true,
  Boolean $public_ssh     = false,
  Boolean $vpn_client     = true,

  # System settings
  Enum['off', 'sway', 'xmonad']  $autologin           = xmonad,
  Enum['grub', 'systemd']        $bootloader          = grub,
  Integer[0]                     $boot_menu_delay     = 3,
  Optional[Integer]              $cpus                = undef,
  Optional[String]               $dtb_file            = undef,
  Array[String]                  $external_interfaces = [],
  Boolean                        $isolate_smt         = false,
  Enum['persistent', 'volatile'] $journal             = persistent,
  Hash[String, Nest::Kconfig]    $kernel_config       = {},
  Array[String]                  $kernel_cmdline      = [],
  Boolean                        $kexec               = false,
  Array[String]                  $reset_filter_rules  = [],
  Enum['tcp', 'udp']             $vpn_transport       = udp,
  Boolean                        $wifi                = false,
  Optional[Sensitive[Hash]]      $wlans               = undef,

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
  Float            $text_scaling_factor = $gui_scaling_factor,
  Array[String]    $monitor_layout      = [],
  Optional[String] $primary_monitor     = undef,
) {
  if $kernel_tag =~ /v([\d.]+(-rc\d+)?)/ {
    $kernel_version = $1
  } else {
    fail("Failed to determine kernel version from the tag '${kernel_tag}'")
  }

  $dpi = Integer(inline_template('<%= (@text_scaling_factor * 96.0).round %>'))
  $gui_scaling_factor_rounded = Integer(inline_template('<%= @gui_scaling_factor.round %>'))
  $text_scaling_factor_percent_of_gui = Float(inline_template('<%= (@dpi / (@gui_scaling_factor * 96.0)).round(3) %>'))
  $text_scaling_factor_percent_of_rounded_gui = Float(inline_template('<%= (@dpi / (@gui_scaling_factor_rounded * 96.0)).round(3) %>'))

  $console_font_sizes        = [16, 18, 20, 22, 24, 28, 32]
  $console_font_size_ideal   = 16 * $nest::text_scaling_factor
  $console_font_size_smaller = inline_template('<%= @console_font_sizes.reverse.find(16) { |size| size - @console_font_size_ideal <= 0 } %>')
  $console_font_size         = $facts['virtual'] ? {
    'vmware' => min($console_font_sizes),
    default  => $console_font_size_smaller,
  }

  $cursor_sizes        = [24, 32, 36, 40, 48, 64, 96]
  $cursor_size_ideal   = 24 * $nest::gui_scaling_factor
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
  if $facts['build'] in ['bolt', 'buildah', 'pdk', 'qemu', 'r10k'] {
    contain "nest::tool::${facts['build']}"
  }
}
