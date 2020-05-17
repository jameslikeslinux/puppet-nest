class nest::role::workstation::plasma {
  nest::lib::portage::package_use { 'kde-plasma/plasma-meta':
    use => 'networkmanager',
  }

  package { 'kde-plasma/plasma-meta':
    ensure => installed,
  }

  # SDDM needs access to /dev/nvidiactl to run
  user { 'sddm':
    groups  => 'video',
    require => Package['kde-plasma/plasma-meta'],
  }

  $sddm_conf = @("EOT")
    [Theme]
    Current=breeze
    CursorTheme=breeze_cursors

    [X11]
    ServerArguments=-dpi ${::nest::dpi}
    EnableHiDPI=false

    [Users]
    MaximumUid=1000
    | EOT

  $sddm_theme_conf = @(EOT)
    [General]
    background=/home/james/.wallpaper.png
    type=image
    fontSize=10
    | EOT

  file {
    default:
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => Package['kde-plasma/plasma-meta'],
    ;

    '/etc/sddm.conf':
      content => $sddm_conf,
    ;

    '/etc/sddm.conf.d/kde_settings.conf':
      ensure => absent,
    ;

    '/usr/share/sddm/themes/breeze/theme.conf':
      content => $sddm_theme_conf,
    ;

    '/usr/share/sddm/themes/breeze/theme.conf.user':
      ensure => absent,
    ;
  }

  file_line { 'sddm-background-fillmode':
    path    => '/usr/share/sddm/themes/breeze/Background.qml',
    line    => '        fillMode: Image.Stretch',
    match   => 'fillMode: Image\.',
    require => Package['kde-plasma/plasma-meta'],
  }

  # When system-login is "included" and contains a sufficient auth
  # step, the stack ends there on success.  Making system-login a
  # substack returns control back to the sddm stack so pam_kwallet
  # can be evaluated.
  augeas { 'pam-sddm':
    context => '/files/etc/pam.d/sddm',
    changes => 'setm *[module = "system-login"] control substack',
    require => Package['kde-plasma/plasma-meta'],
  }

  service { 'sddm':
    enable  => true,
    require => [
      User['sddm'],
      File['/etc/sddm.conf'],
      Augeas['pam-sddm'],
    ],
  }

  # Don't build support for online services
  nest::lib::portage::package_use { 'kde-apps/spectacle':
    use => '-kipi',
  }

  package { [
    'kde-apps/ark',
    'kde-apps/dolphin',
    'kde-apps/ffmpegthumbs',
    'kde-apps/gwenview',
    'kde-apps/kwrite',
    'kde-apps/okular',
    'kde-apps/spectacle',
  ]:
    ensure => installed,
  }

  package { 'kde-apps/konsole':
    ensure => absent,
  }
}
