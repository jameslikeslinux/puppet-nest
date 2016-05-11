class nest::profile::workstation::xorg {
  $keyboard_layout = 'us'

  if $::nest::keyboard_layout == 'dvorak' {
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
    $eselect_opengl       = 'nvidia'
    $nvidia_conf_ensure   = 'present'
    $monitors_conf_ensure = 'absent'
  } else {
    $eselect_opengl     = 'xorg-x11'
    $nvidia_conf_ensure = 'absent'
    $monitors_conf_ensure = $monitor_layout ? {
      []      => 'absent',
      default => 'present',
    }
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

  eselect { 'opengl':
    set => $eselect_opengl,
  }
}
