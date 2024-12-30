class nest::gui::packages {
  nest::lib::package { 'app-text/texlive':
    ensure => installed,
    use    => ['extra', 'xetex'],
  }

  nest::lib::package { 'net-dialup/minicom':
    ensure => installed,
  }

  if $facts['profile']['architecture'] in ['amd64', 'arm', 'arm64'] {
    nest::lib::package { 'app-editors/vscode':
      ensure => installed,
    }
  }
}
