class nest::profile::workstation::packages {
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

  package { [
    'media-gfx/displaycal',
    'x11-misc/xdotool',
  ]:
    ensure => installed,
  }
}
