class nest::role::workstation::input {
  $hwdb_ensure = $facts['profile']['platform'] ? {
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
  }

  exec { 'udev-hwdb-update':
    command     => '/bin/udevadm hwdb --update',
    refreshonly => true,
  }

  file { '/etc/X11/xinit/xinitrc.d/99-xmodmap':
    ensure => absent,
  }
}
