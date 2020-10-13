class nest::role::workstation {
  contain '::nest::role::workstation::chromium'
  contain '::nest::role::workstation::firefox'

  case $facts['osfamily'] {
    'Gentoo': {
      contain '::nest::role::workstation::bluetooth'
      contain '::nest::role::workstation::cups'
      contain '::nest::role::workstation::cursor'
      contain '::nest::role::workstation::dunst'
      contain '::nest::role::workstation::fonts'
      contain '::nest::role::workstation::input'
      contain '::nest::role::workstation::lastpass'
      contain '::nest::role::workstation::libvirt'
      contain '::nest::role::workstation::media'
      contain '::nest::role::workstation::packages'
      contain '::nest::role::workstation::policykit'
      contain '::nest::role::workstation::plasma'
      contain '::nest::role::workstation::pulseaudio'
      contain '::nest::role::workstation::sway'
      contain '::nest::role::workstation::terms'
      contain '::nest::role::workstation::xmonad'
      contain '::nest::role::workstation::xorg'
      contain '::nest::role::workstation::ydotool'
      contain '::nest::role::workstation::zoom'

      if $::nest::barrier_config {
        contain '::nest::role::workstation::barrier'
      }

      # XXX: Need to figure out the role for qemu in other archs.  Should it go
      # into the base config?
      if $facts['architecture'] == 'amd64' {
        contain '::nest::role::workstation::qemu'
      }

      # Plasma pulls in xorg-drivers which builds nvidia-drivers which requires
      # a built kernel and needs to come before building the initramfs.
      Class['::nest::base::kernel']
      -> Class['::nest::role::workstation::plasma']
      -> Class['::nest::base::dracut']

      # Plasma installs pulseaudio, so we don't need to manage it separately
      Class['::nest::role::workstation::plasma']
      -> Class['::nest::role::workstation::pulseaudio']

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

      # NetworkManager, systemd, libvirt pull in policykit
      Class['::nest::base']
      -> Class['::nest::role::workstation::policykit']
    }
  }
}
