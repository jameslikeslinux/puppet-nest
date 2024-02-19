class nest::gui::plasma {
  nest::lib::package { 'kde-plasma/plasma-meta':
    ensure => installed,
    use    => ['-display-manager', '-firewall', '-networkmanager'],
  }

  # Don't build support for online services
  nest::lib::package_use { 'kde-apps/spectacle':
    use => '-kipi',
  }

  package { [
    'kde-apps/ark',
    'kde-apps/dolphin',
    'kde-apps/ffmpegthumbs',
    'kde-apps/gwenview',
    'kde-apps/kdialog',
    'kde-apps/kwrite',
    'kde-apps/okular',
    'kde-apps/spectacle',
  ]:
    ensure => installed,
  }


  # XXX cleanup
  service { 'sddm':
    ensure => stopped,
    enable => false,
  }
  ->
  package { 'x11-misc/sddm':
    ensure  => absent,
    require => Nest::Lib::Package['kde-plasma/plasma-meta'],
  }
  ->
  file { [
    '/etc/sddm.conf',
    '/etc/sddm.conf.d',
  ]:
    ensure => absent,
    force  => true,
  }
}
