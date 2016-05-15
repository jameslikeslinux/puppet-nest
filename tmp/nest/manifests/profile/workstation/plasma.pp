class nest::profile::workstation::plasma {
  nest::portage::package_use { 'kde-plasma/plasma-meta':
    use => 'networkmanager',
  }

  package { 'kde-plasma/plasma-meta':
    ensure => installed,
  }

  $kwin_triple_buffer_ensure = $::nest::video_card ? {
    'nvidia' => 'present',
    default  => 'absent',
  }

  file { '/etc/plasma/startup/10-kwin-triple-buffer.sh':
    ensure  => $kwin_triple_buffer_ensure,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "export KWIN_TRIPLE_BUFFER=1\n",
    require => Package['kde-plasma/plasma-meta'],
  }

  $scaling = @("EOT")
    export GDK_SCALE=${::nest::scaling_factor_rounded}
    export GDK_DPI_SCALE=${::nest::scaling_factor_percent_of_rounded}
    export QT_DEVICE_PIXEL_RATIO=${::nest::scaling_factor_rounded}
    | EOT

  file { '/etc/plasma/startup/10-scaling.sh':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $scaling,
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

    [XDisplay]
    ServerArguments=-dpi ${::nest::dpi}
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
}
