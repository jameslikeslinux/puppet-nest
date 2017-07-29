class nest::profile::workstation::plasma {
  nest::portage::package_use { 'kde-plasma/plasma-meta':
    use => 'networkmanager',
  }

  package { 'kde-plasma/plasma-meta':
    ensure => installed,
  }

  # XXX: This is also managed in xinitrc.d, but /usr/bin/startkde overrides it.
  # Then it sources scripts in /etc/plasma/startup, so we can re-set it there.
  file { '/etc/plasma/startup/10-scaling.sh':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "export QT_AUTO_SCREEN_SCALE_FACTOR=1\n",
    require => Package['kde-plasma/plasma-meta'],
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

    [Users]
    MaximumUid=1000
    | EOT

  file { '/etc/sddm.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $sddm_conf,
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

  nest::portage::package_use { 'kde-apps/dolphin':
    use => 'thumbnail',
  }

  # Don't build support for online services
  nest::portage::package_use { 'kde-apps/spectacle':
    use => '-kipi',
  }

  package { [
    'kde-apps/ark',
    'kde-apps/dolphin',
    'kde-apps/gwenview',
    'kde-apps/konsole',
    'kde-apps/kwrite',
    'kde-apps/okular',
    'kde-apps/spectacle',
  ]:
    ensure => installed,
  }
}
