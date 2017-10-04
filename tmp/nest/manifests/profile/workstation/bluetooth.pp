class nest::profile::workstation::bluetooth {
  file_line { 'bluetooth-autoenable':
    path   => '/etc/bluetooth/main.conf',
    line   => 'AutoEnable=true',
    match  => '^#?AutoEnable=',
    notify => Service['bluetooth'],
  }

  service { 'bluetooth':
    enable => true,
  }

  # http://plugable.com/2014/06/23/plugable-usb-bluetooth-adapter-solving-hfphsp-profile-issues-on-linux/
  exec { 'wget-plugable-bluetooth-firmware':
    command => '/usr/bin/wget https://s3.amazonaws.com/plugable/bin/fw-0a5c_21e8.hcd -O /lib/firmware/brcm/BCM20702A1-0a5c-21e8.hcd',
    creates => '/lib/firmware/brcm/BCM20702A1-0a5c-21e8.hcd',
    require => Package['sys-kernel/linux-firmware'],
  }
}
