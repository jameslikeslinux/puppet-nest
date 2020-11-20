class nest::role::workstation::bluetooth {
  file_line { 'bluetooth-autoenable':
    path   => '/etc/bluetooth/main.conf',
    line   => 'AutoEnable=true',
    match  => '^#?AutoEnable=',
    notify => Service['bluetooth'],
  }

  service { 'bluetooth':
    enable => true,
  }
}
