class nest::gui::dunst {
  package { 'x11-misc/dunst':
    ensure => installed,
  }

  # XXX cleanup
  nest::lib::package { 'gnome-base/librsvg':
    world => false,
  }
}
