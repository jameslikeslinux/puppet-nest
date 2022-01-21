class nest::role::workstation::plasma {
  nest::lib::package_use { 'kde-plasma/plasma-meta':
    use => ['-firewall', '-networkmanager']
  }

  package { 'kde-plasma/plasma-meta':
    ensure => installed,
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

  if $::nest::autologin != off {
    $session = $::nest::autologin ? {
      xmonad  => 'plasma',
      default => $::nest::autologin,
    }

    $sddm_autologin_conf = @("AUTOLOGIN")

      [Autologin]
      User=james
      Session=${session}
      | AUTOLOGIN
  }

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
      content => "${sddm_conf}${sddm_autologin_conf}",
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

  # Theme tweaks
  file_line {
    default:
      require => Package['kde-plasma/plasma-meta'],
    ;

    'sddm-background-fillmode':
      path  => '/usr/share/sddm/themes/breeze/Background.qml',
      line  => '        fillMode: Image.Stretch',
      match => 'fillMode: Image\.',
    ;

    'sddm-disable-wallpaperfader':
      path  => '/usr/share/sddm/themes/breeze/Main.qml',
      line  => '            visible: false',
      match => 'visible: config\.type === "image"',
    ;

    'lockscreen-disable-wallpaperfader':
      path  => '/usr/share/plasma/look-and-feel/org.kde.breeze.desktop/contents/lockscreen/LockScreenUi.qml',
      line  => '            visible: false',
      after => 'WallpaperFader {',
    ;

    'sddm-load-xresources':
      path => '/usr/share/sddm/scripts/Xsetup',
      line => 'xrdb -merge /etc/X11/Xresources',
    ;
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
      File['/etc/sddm.conf'],
      Augeas['pam-sddm'],
    ],
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
}
