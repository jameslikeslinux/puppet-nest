class nest::profile::workstation::xorg {
  $keyboard_layout = 'us'

  if $::nest::dvorak {
    $keyboard_variant = 'dvorak'
  }

  # This file is ordinarily managed by localectl.
  # This tries to be compatible.
  file { '/etc/X11/xorg.conf.d/00-keyboard.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('nest/xorg/keyboard.conf.erb'),
  }

  $monitor_layout  = $::nest::monitor_layout
  $primary_monitor = $::nest::primary_monitor
  $video_card      = $::nest::video_card

  if $video_card == 'nvidia' {
    $eselect_opengl            = 'nvidia'
    $nvidia_conf_ensure        = 'present'
    $monitors_conf_ensure      = 'absent'
    $kwin_triple_buffer_ensure = 'present'
  } else {
    $eselect_opengl            = 'xorg-x11'
    $nvidia_conf_ensure        = 'absent'
    $monitors_conf_ensure      = $monitor_layout ? {
      []      => 'absent',
      default => 'present',
    }
    $kwin_triple_buffer_ensure = 'absent'
  }

  file { '/etc/X11/xorg.conf.d/10-nvidia.conf':
    ensure  => $nvidia_conf_ensure,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('nest/xorg/nvidia.conf.erb'),
  }

  file { '/etc/X11/xorg.conf.d/10-monitors.conf':
    ensure  => $monitors_conf_ensure,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('nest/xorg/monitors.conf.erb'),
  }

  file { '/etc/X11/xorg.conf.d/10-libinput.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('nest/xorg/libinput.conf.erb'),
  }

  file { '/etc/X11/xinit/xinitrc.d/10-kwin-triple-buffer':
    ensure  => $kwin_triple_buffer_ensure,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => "#!/bin/bash\nexport KWIN_TRIPLE_BUFFER=1\n",
  }

  $qt_font_dpi = inline_template('<%= (scope.lookupvar("nest::text_scaling_factor_percent_of_gui") * 96).round %>')
  $scaling = @("EOT")
    #!/bin/bash
    export GDK_SCALE=${::nest::gui_scaling_factor_rounded}
    export GDK_DPI_SCALE=${::nest::text_scaling_factor_percent_of_rounded_gui}
    export QT_AUTO_SCREEN_SCALE_FACTOR=0
    export QT_SCALE_FACTOR=${::nest::gui_scaling_factor}
    export QT_FONT_DPI=${qt_font_dpi}
    | EOT

  file { '/etc/X11/xinit/xinitrc.d/10-scaling':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $scaling,
  }

  eselect { 'opengl':
    set => $eselect_opengl,
  }

  package { [
    'x11-apps/xmodmap',
    'x11-apps/xrandr',
    'x11-misc/vdpauinfo',
  ]:
    ensure => installed,
  }

}
