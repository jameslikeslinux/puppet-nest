class nest::role::workstation::xorg {
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

  # Switch to xf86-video-modesetting DDX
  package { 'x11-drivers/xf86-video-intel':
    ensure => 'absent',
  }

  file { '/etc/X11/xorg.conf.d/10-intel.conf':
    ensure => 'absent',
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/xorg/intel.conf',
  }

  if $video_card == 'nvidia' {
    $nvidia_conf_ensure        = 'present'
    $monitors_conf_ensure      = 'absent'
    $kwin_triple_buffer_ensure = 'present'
  } else {
    $nvidia_conf_ensure        = 'absent'
    $monitors_conf_ensure      = $monitor_layout ? {
      []      => 'absent',
      default => 'present',
    }
    $kwin_triple_buffer_ensure = 'absent'
  }

  file { '/etc/modprobe.d/nouveau.conf':
    ensure => absent,
    notify => Class['nest::base::bootloader'],
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
    export XCURSOR_SIZE=${::nest::cursor_size}
    | EOT

  file { '/etc/X11/xinit/xinitrc.d/10-scaling':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $scaling,
  }

  package { 'x11-apps/xeyes':
    ensure => absent,
  }

  package { [
    'x11-apps/xev',
    'x11-apps/xinput',
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
    $mst_workaround = absent
  }

  # Workaround DP 1.2 MST sleep issue
  file_line { 'sddm-workaround-mst-sleep-issue':
    ensure => $mst_workaround,
    path   => '/usr/share/sddm/scripts/Xsetup',
    line   => 'xset dpms force off && xset dpms force on',
  }

  # Load i2c-dev for controlling monitors
  file { '/etc/modules-load.d/i2c-dev.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "i2c-dev\n",
  }

  package { 'app-misc/ddcutil':
    ensure => installed,
  }
}
