class nest::role::workstation::bluetooth {
  nest::lib::package { 'net-wireless/bluez':
    ensure => installed,
  }
  ->
  file_line { 'bluetooth-autoenable':
    path  => '/etc/bluetooth/main.conf',
    line  => 'AutoEnable=true',
    match => '^#?AutoEnable=',
  }
  ~>
  service { 'bluetooth':
    enable => true,
  }

  if $facts['profile']['platform'] == 'raspberrypi4' {
    file { '/etc/systemd/system/btattach.service':
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/nest/bluetooth/btattach.service',
    }
    ~>
    ::nest::lib::systemd_reload { 'bluetooth': }
    ->
    service { 'btattach':
      enable  => true,
    }
  }
}
