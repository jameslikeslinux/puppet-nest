class nest::profile::workstation::xorg {
  $layout = $::nest::keyboard_layout

  if $layout == 'dvorak' {
    $variant = 'dvorak'
  }

  # This file is ordinarily managed by localectl.
  # This tries to be compatible.
  file { '/etc/X11/xorg.conf.d/00-keyboard.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('nest/xorg/keyboard.conf.erb'),
  }
}
