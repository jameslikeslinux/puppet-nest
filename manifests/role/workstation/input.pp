class nest::role::workstation::input {
  $keyboard_hwdb = @(KEYBOARD_HWDB)
    # Pinebook Pro
    evdev:input:b0003v258Ap001E*
     KEYBOARD_KEY_700a5=brightnessdown
     KEYBOARD_KEY_700a6=brightnessup
     KEYBOARD_KEY_70066=sleep
    | KEYBOARD_HWDB

  file { '/etc/udev/hwdb.d/61-keyboard-local.hwdb':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $keyboard_hwdb,
    notify  => Exec['udev-hwdb-update'],
  }

  file { '/etc/udev/hwdb.d/71-mouse-local.hwdb':
    ensure => absent,
    notify => Exec['udev-hwdb-update'],
  }

  exec { 'udev-hwdb-update':
    command     => '/bin/udevadm hwdb --update',
    refreshonly => true,
  }

  $xmodmap_ensure = $::nest::mouse ? {
    'mxmaster' => file,
    default    => absent,
  }

  $xmodmap_content = @(EOT)
    #!/bin/sh
    xmodmap -e 'pointer = 1 2 3 4 5 7 6'
    | EOT

  file { '/etc/X11/xinit/xinitrc.d/99-xmodmap':
    ensure  => $xmodmap_ensure,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $xmodmap_content,
  }
}
