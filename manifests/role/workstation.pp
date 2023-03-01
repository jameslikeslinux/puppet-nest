class nest::role::workstation {
  contain 'nest::role::workstation::chrome'
  contain 'nest::role::workstation::firefox'

  case $facts['os']['family'] {
    'Gentoo': {
      contain 'nest::role::workstation::bitwarden'
      contain 'nest::role::workstation::cups'
      contain 'nest::role::workstation::cursor'
      contain 'nest::role::workstation::dunst'
      contain 'nest::role::workstation::fonts'
      contain 'nest::role::workstation::greetd'
      contain 'nest::role::workstation::input'
      contain 'nest::role::workstation::media'
      contain 'nest::role::workstation::packages'
      contain 'nest::role::workstation::policykit'
      contain 'nest::role::workstation::plasma'
      contain 'nest::role::workstation::pipewire'
      contain 'nest::role::workstation::sway'
      contain 'nest::role::workstation::terminals'
      contain 'nest::role::workstation::virtualization'
      contain 'nest::role::workstation::xmonad'
      contain 'nest::role::workstation::xorg'
      contain 'nest::role::workstation::zoom'

      # Plasma installs default cursors which we want to replace
      Class['nest::role::workstation::plasma']
      -> Class['nest::role::workstation::cursor']

      # Manage input settings after xorg
      Class['nest::role::workstation::xorg']
      -> Class['nest::role::workstation::input']

      # virt-viewer pulls in zfs
      Class['nest::base::zfs']
      -> Class['nest::role::workstation::virtualization']
    }
  }
}
