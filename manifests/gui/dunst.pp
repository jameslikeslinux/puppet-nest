class nest::gui::dunst {
  nest::lib::package { 'x11-misc/dunst':
    ensure => installed,
  }
}
