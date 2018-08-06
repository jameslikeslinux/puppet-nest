class nest::profile::workstation::xorg {
  $keyboard_layout = 'us'

  if $::nest::dvorak {
    $keyboard_variant = 'dvorak'
  }

  $keyboard_options = $::nest::swap_alt_win ? {
    true    => 'ctrl:nocaps,terminate:ctrl_alt_bksp,altwin:swap_alt_win',
    default => 'ctrl:nocaps,terminate:ctrl_alt_bksp',
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

  $intel_ensure = $video_card ? {
    'intel' => present,
    default => absent,
  }

  # Whatever people say about the state and quality of this driver, it just
  # works.  SNA/DRI2 + the TearFree option enables perfectly tear-free
  # everything, even without a compositor.  It's also very fast.  The
  # modesetting driver with DRI3 just isn't there yet.
  package { 'x11-drivers/xf86-video-intel':
    ensure => $intel_ensure,
  }

  file { '/etc/X11/xorg.conf.d/10-intel.conf':
    ensure => $intel_ensure,
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/xorg/intel.conf',
  }

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

  package { 'x11-apps/xeyes':
    ensure => absent,
  }

  package { [
    'x11-apps/xlogo',
    'x11-apps/xkill',
    'x11-apps/xmodmap',
    'x11-apps/xrandr',
    'x11-apps/xwininfo',
    'x11-misc/vdpauinfo',
    'x11-misc/xdotool',
  ]:
    ensure => installed,
  }

  # Workaround xdotool layout issue
  # See: https://github.com/jordansissel/xdotool/issues/211
  file { '/etc/X11/xinit/xinitrc.d/99-setxkbmap':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => "#!/bin/sh\nsetxkbmap -synch\n",
  }

  if $video_card == 'nvidia' and $primary_monitor =~ /\./ {
    $mst_workaround = present
  } else {
    $mst_workaronud = absent
  }

  # Workaround DP 1.2 MST sleep issue
  file_line { 'sddm-workaround-mst-sleep-issue':
    ensure => $mst_workaround,
    path   => '/usr/share/sddm/scripts/Xsetup',
    line   => 'xset dpms force off && xset dpms force on',
  }
}
