class nest::profile::workstation::xmonad {
  nest::portage::package_use { 'x11-misc/xmobar':
    use => 'xft',
  }

  package { [
    'x11-wm/xmonad',
    'x11-wm/xmonad-contrib',
    'x11-misc/xmobar',
    'x11-misc/rofi',
  ]:
    ensure => installed,
  }
}
