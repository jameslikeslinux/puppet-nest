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

  $gtk_scaling = @("EOT")
    export GDK_SCALE=${::nest::scaling_factor_rounded}
    export GDK_DPI_SCALE=${::nest::scaling_factor_percent_of_rounded}
    | EOT

  file { '/etc/plasma/startup/10-gtk-scaling.sh':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $gtk_scaling,
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

  service { 'sddm':
    enable  => true,
    require => File['/etc/sddm.conf'],
  }
}
