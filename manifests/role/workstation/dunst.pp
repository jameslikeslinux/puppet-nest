class nest::role::workstation::dunst {
  package { 'gnome-base/librsvg':
    ensure => installed,
  }

  package { 'x11-misc/dunst':
    ensure => installed,
  }


  #
  # XXX: Cleanup scaled icons in favor of native scaling
  #
  file { '/usr/share/dunst':
    ensure => absent,
    force  => true,
  }
}
