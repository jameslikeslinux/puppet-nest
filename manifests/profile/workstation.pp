class nest::profile::workstation {
  contain '::nest::profile::workstation::chromium'
  contain '::nest::profile::workstation::firefox'

  case $facts['osfamily'] {
    'Gentoo': {
      contain '::nest::profile::workstation::bluetooth'
      contain '::nest::profile::workstation::cups'
      contain '::nest::profile::workstation::cursor'
      contain '::nest::profile::workstation::dunst'
      contain '::nest::profile::workstation::fonts'
      contain '::nest::profile::workstation::lastpass'
      contain '::nest::profile::workstation::libvirt'
      contain '::nest::profile::workstation::media'
      contain '::nest::profile::workstation::mouse'
      contain '::nest::profile::workstation::packages'
      contain '::nest::profile::workstation::policykit'
      contain '::nest::profile::workstation::plasma'
      contain '::nest::profile::workstation::pulseaudio'
      contain '::nest::profile::workstation::thunderbird'
      contain '::nest::profile::workstation::urxvt'
      contain '::nest::profile::workstation::xmonad'
      contain '::nest::profile::workstation::xorg'

      if $::nest::barrier_config {
        contain '::nest::profile::workstation::barrier'
      }

      # Plasma pulls in xorg-drivers which builds nvidia-drivers which requires
      # a built kernel and needs to come before building the initramfs.
      Class['::nest::profile::base::kernel']
      -> Class['::nest::profile::workstation::plasma']
      -> Class['::nest::profile::base::dracut']

      # Plasma installs pulseaudio, so we don't need to manage it separately
      Class['::nest::profile::workstation::plasma']
      -> Class['::nest::profile::workstation::pulseaudio']

      # Plasma installs xorg-server, so we don't need to manage it separately
      Class['::nest::profile::workstation::plasma']
      -> Class['::nest::profile::workstation::xorg']

      # Plasma installs default cursors which we want to replace
      Class['::nest::profile::workstation::plasma']
      -> Class['::nest::profile::workstation::cursor']

      # Plasma installs icons which we want to copy and transform for dunst
      Class['::nest::profile::workstation::plasma']
      -> Class['::nest::profile::workstation::dunst']

      # Manage mouse settings after xorg
      Class['::nest::profile::workstation::xorg']
      -> Class['::nest::profile::workstation::mouse']

      # NetworkManager pulls in bluez
      Class['::nest::profile::base::network']
      -> Class['::nest::profile::workstation::bluetooth']

      # NetworkManager, systemd, libvirt pull in policykit
      Class['::nest::profile::base']
      -> Class['::nest::profile::workstation::policykit']

      if $facts['dmi']['chassis']['type'] in ['Laptop', 'Notebook'] {
        contain '::nest::profile::workstation::tlp'
      }
    }
  }
}
