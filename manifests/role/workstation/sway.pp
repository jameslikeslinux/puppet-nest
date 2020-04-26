class nest::role::workstation::sway {
  nest::lib::portage::package_use { 'gui-wm/sway':
    use => ['-swaybar', '-swaylock', '-swayidle'],
  }

  package { [
    'gui-wm/sway',
    'gui-apps/waybar',
  ]:
    ensure => installed,
  }
}
