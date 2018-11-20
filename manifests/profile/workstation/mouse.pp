class nest::profile::workstation::mouse {
  $mouse_hwdb = @(EOT)
    # Logitech MX Master
    mouse:usb:v046dp4041:name:Logitech MX Master:
      MOUSE_DPI=1000@166

    # Lenovo Thinkpad X1 Carbon 4th gen
    evdev:name:TPPS/2 IBM TrackPoint:dmi:bvn*:bvr*:bd*:svnLENOVO:pn*:pvrThinkPadX1Carbon4th:*
      POINTINGSTICK_SENSITIVITY=200
      POINTINGSTICK_CONST_ACCEL=1.0
    | EOT

  file { '/etc/udev/hwdb.d/71-mouse-local.hwdb':
    # These customizations are now in upstream udev
    ensure  => absent,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $mouse_hwdb,
    notify  => Exec['udev-hwdb-update'],
  }

  exec { 'udev-hwdb-update':
    command     => '/usr/bin/udevadm hwdb --update',
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
