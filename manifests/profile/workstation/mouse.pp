class nest::profile::workstation::mouse {
  $mouse_hwdb = @(EOT)
    # Logitech Anywhere MX
    mouse:usb:v046dpc52b:name:Logitech Unifying Device. Wireless PID:1017:
    mouse:usb:v046dp1017:name:Logitech Anywhere MX:
    # Logitech Anywhere MX 2S
    mouse:usb:v046dp406a:name:Logitech MX Anywhere 2S:
    MOUSE_WHEEL_CLICK_ANGLE=20
    | EOT

  file { '/etc/udev/hwdb.d/71-mouse-local.hwdb':
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
