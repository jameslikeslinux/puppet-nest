class nest::profile::workstation::urxvt {
  file { [
    '/etc/portage/patches/x11-terms',
    '/etc/portage/patches/x11-terms/rxvt-unicode',
  ]:
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  file { '/etc/portage/patches/x11-terms/rxvt-unicode/sgr-mouse-mode.patch':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/urxvt/sgr-mouse-mode.patch',
  }

  nest::lib::portage::package_use { 'x11-terms/rxvt-unicode':
    use => ['256-color', 'alt-font-width', 'secondary-wheel', 'unicode3', '-vanilla', 'xft'],
  }

  package { [
    'x11-terms/rxvt-unicode',
    'x11-misc/urxvt-font-size',
    'x11-misc/urxvt-perls',
  ]:
    ensure  => installed,
    require => File['/etc/portage/patches/x11-terms/rxvt-unicode/sgr-mouse-mode.patch'],
  }
}
