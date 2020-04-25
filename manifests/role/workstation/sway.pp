class nest::role::workstation::sway {
  nest::lib::portage::package_use { 'gui-wm/sway':
    use => '-swaybar',
  }

  package { [
    'gui-wm/sway',
    'gui-apps/waybar',
  ]:
    ensure => installed,
  }
}
