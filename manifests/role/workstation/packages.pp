class nest::role::workstation::packages {
  nest::lib::package_use { 'app-text/texlive':
    use => ['extra', 'xetex'],
  }

  package { 'app-text/texlive':
    ensure => installed,
  }
}
