class nest::role::workstation {
  contain '::nest::role::workstation::chromium'
  contain '::nest::role::workstation::firefox'

  case $facts['osfamily'] {
    'Gentoo': {
      contain '::nest::role::workstation::bitwarden'
      contain '::nest::role::workstation::bluetooth'
      contain '::nest::role::workstation::cups'
      contain '::nest::role::workstation::cursor'
      contain '::nest::role::workstation::dunst'
      contain '::nest::role::workstation::fonts'
      contain '::nest::role::workstation::input'
      contain '::nest::role::workstation::media'
      contain '::nest::role::workstation::packages'
      contain '::nest::role::workstation::policykit'
      contain '::nest::role::workstation::plasma'
      contain '::nest::role::workstation::pipewire'
      contain '::nest::role::workstation::sway'
      contain '::nest::role::workstation::terminals'
      contain '::nest::role::workstation::virtualization'
      contain '::nest::role::workstation::xmonad'
      contain '::nest::role::workstation::xorg'
      contain '::nest::role::workstation::ydotool'
      contain '::nest::role::workstation::zoom'

      # Plasma installs xorg-server, so we don't need to manage it separately
      Class['::nest::role::workstation::plasma']
      -> Class['::nest::role::workstation::xorg']

      # Plasma installs default cursors which we want to replace
      Class['::nest::role::workstation::plasma']
      -> Class['::nest::role::workstation::cursor']

      # Plasma installs icons which we want to copy and transform for dunst
      Class['::nest::role::workstation::plasma']
      -> Class['::nest::role::workstation::dunst']

      # Manage input settings after xorg
      Class['::nest::role::workstation::xorg']
      -> Class['::nest::role::workstation::input']

      # NetworkManager pulls in bluez
      Class['::nest::base::network']
      -> Class['::nest::role::workstation::bluetooth']

      # NetworkManager, systemd pull in policykit
      Class['::nest::base']
      -> Class['::nest::role::workstation::policykit']
    }
  }
}
