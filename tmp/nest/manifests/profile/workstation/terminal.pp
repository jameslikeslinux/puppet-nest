class nest::profile::workstation::terminal {
  nest::portage::package_use { 'x11-terms/rxvt-unicode':
    use => ['256-color', 'alt-font-width', 'secondary-wheel', 'unicode3', '-vanilla', 'xft'],
  }

  package { [
    'x11-terms/rxvt-unicode',
    'x11-misc/urxvt-font-size',
    'x11-misc/urxvt-perls',
  ]:
    ensure => installed,
  }
}
