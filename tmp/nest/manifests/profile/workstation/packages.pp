class nest::profile::workstation::packages {
  nest::portage::package_use { 'net-im/pidgin':
    use => 'networkmanager',
  }

  package { 'net-im/pidgin':
    ensure => installed,
  }

  package { 'x11-plugins/pidgin-skypeweb':
    ensure  => installed,
    require => Package['net-im/pidgin'],
  }

  nest::portage::package_use { 'app-text/texlive':
    use => ['extra', 'xetex'],
  }

  package { 'app-text/texlive':
    ensure => installed,
  }
}
