class nest::role::workstation::packages {
  nest::lib::portage::package_use { 'app-text/texlive-core':
    use => 'xetex',
  }

  nest::lib::portage::package_use { 'app-text/texlive':
    use => ['extra', 'xetex'],
  }

  package { 'app-text/texlive':
    ensure  => installed,
    require => Nest::Lib::Portage::Package_use['app-text/texlive-core'],
  }
}
