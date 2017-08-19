class nest::profile::workstation::xmonad {
  nest::portage::package_use { 'x11-misc/xmobar':
    use => 'xft',
  }

  package { [
    'x11-wm/xmonad',
    'x11-wm/xmonad-contrib',
    'x11-misc/compton',
    'x11-misc/dunst',
    'x11-misc/rofi',
    'x11-misc/taffybar',
  ]:
    ensure => installed,
  }

  package { 'x11-misc/xmobar':
    ensure => absent,
  }
}
