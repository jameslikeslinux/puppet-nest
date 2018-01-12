class nest::profile::workstation::packages {
  nest::portage::package_use { 'net-im/pidgin':
    ensure => absent,
    use    => 'networkmanager',
  }

  package { 'net-im/pidgin':
    ensure => absent,
  }

  package { 'x11-plugins/pidgin-skypeweb':
    ensure => absent,
    before => Package['net-im/pidgin'],
  }

  package { 'net-im/skypeforlinux':
    ensure => absent,
  }

  nest::portage::package_use { 'app-text/texlive-core':
    use => 'xetex',
  }

  nest::portage::package_use { 'app-text/texlive':
    use => ['extra', 'xetex'],
  }

  package { 'app-text/texlive':
    ensure  => installed,
    require => Nest::Portage::Package_use['app-text/texlive-core'],
  }

  package { 'media-gfx/displaycal':
    ensure => installed,
  }
}
