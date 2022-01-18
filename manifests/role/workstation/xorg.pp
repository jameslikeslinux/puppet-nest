class nest::role::workstation::xorg {
  file { '/etc/X11/xorg.conf.d':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

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

  $monitors_conf_ensure = $monitor_layout ? {
    []      => 'absent',
    default => 'present',
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

  $qt_font_dpi = inline_template('<%= (scope.lookupvar("nest::text_scaling_factor_percent_of_gui") * 96).round %>')
  $scaling = @("EOT"/$)
    #!/bin/bash
    export GDK_SCALE=${::nest::gui_scaling_factor_rounded}
    export GDK_DPI_SCALE=${::nest::text_scaling_factor_percent_of_rounded_gui}
    export QT_SCALE_FACTOR=${::nest::gui_scaling_factor}
    export QT_FONT_DPI=${qt_font_dpi}
    export XCURSOR_SIZE=${::nest::cursor_size}
    kwriteconfig5 --file \$HOME/.config/kcminputrc --group Mouse --key cursorSize ${::nest::cursor_size}
    | EOT

  file { '/etc/X11/xinit/xinitrc.d/10-scaling':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $scaling,
  }

  package { 'x11-misc/vdpauinfo':
    ensure => absent,
  }

  package { [
    'x11-apps/mesa-progs',
    'x11-apps/xev',
    'x11-apps/xinput',
    'x11-apps/xkill',
    'x11-apps/xlogo',
    'x11-apps/xmodmap',
    'x11-apps/xrandr',
    'x11-apps/xwininfo',
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

  # Workaround VMware DPI resets on screen size change
  if $facts['virtual'] == 'vmware' {
    file {
      default:
        owner => 'root',
        group => 'root',
      ;

      '/usr/local/bin/vmware-keep-dpi':
        mode    => '0755',
        content => epp('nest/xorg/vmware-keep-dpi.zsh.epp', { dpi => $::nest::dpi }),
      ;

      '/etc/systemd/user/vmware-keep-dpi.service':
        mode   => '0644',
        source => 'puppet:///modules/nest/xorg/vmware-keep-dpi.service',
      ;
    }
    ->
    exec { 'systemd-enable-vmware-keep-dpi':
      command => '/bin/systemctl --user --global enable vmware-keep-dpi',
      creates => '/etc/systemd/user/graphical-session.target.wants/vmware-keep-dpi.service',
    }
  } else {
    exec { 'systemd-disable-vmware-keep-dpi':
      command => '/bin/systemctl --user --global disable vmware-keep-dpi',
      onlyif  => '/usr/bin/test -f /etc/systemd/user/graphical-session.target.wants/vmware-keep-dpi.service',
    }
    ->
    file { [
      '/etc/systemd/user/vmware-keep-dpi.service',
      '/usr/local/bin/vmware-keep-dpi',
    ]:
      ensure => absent,
    }
  }
}
