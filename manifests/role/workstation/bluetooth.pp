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

  if $::platform == 'raspberrypi' {
    file { '/etc/systemd/system/btattach.service':
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/nest/bluetooth/btattach.service',
      notify => Nest::Lib::Systemd_reload['bluetooth'],
    }

    ::nest::lib::systemd_reload { 'bluetooth': }

    service { 'btattach':
      enable  => true,
      require => Nest::Lib::Systemd_reload['bluetooth'],
    }
  }
}
