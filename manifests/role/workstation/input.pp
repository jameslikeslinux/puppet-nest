class nest::role::workstation::input {
  $hwdb_ensure = $::nest::platform ? {
    'pinebookpro' => present,
    default       => absent,
  }

  $evdev_hwdb = @(EVDEV_HWDB)
    # Pinebook Pro
    evdev:input:b0003v258Ap001E*
     EVDEV_ABS_00=5:1395:15
     EVDEV_ABS_01=8:911:15
     EVDEV_ABS_35=5:1395:15
     EVDEV_ABS_36=8:911:15
    | EVDEV_HWDB

  $keyboard_hwdb = @(KEYBOARD_HWDB)
    # Pinebook Pro
    evdev:input:b0003v258Ap001E*
     KEYBOARD_KEY_700a5=brightnessdown
     KEYBOARD_KEY_700a6=brightnessup
     KEYBOARD_KEY_70066=sleep
    | KEYBOARD_HWDB

  file {
    default:
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      notify  => Exec['udev-hwdb-update'],
    ;

    '/etc/udev/hwdb.d/61-evdev-local.hwdb':
      ensure  => $hwdb_ensure,
      content => $evdev_hwdb,
    ;

    '/etc/udev/hwdb.d/61-keyboard-local.hwdb':
      ensure  => $hwdb_ensure,
      content => $keyboard_hwdb,
    ;

    '/etc/udev/hwdb.d/71-mouse-local.hwdb':
      ensure => absent,
    ;
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
