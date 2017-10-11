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

  # Sometimes the bluetooth adapter prevents suspension:
  #   pci_pm_suspend(): hcd_pci_suspend+0x0/0x30 returns -16
  #   dpm_run_callback(): pci_pm_suspend+0x0/0x130 returns -16
  #   PM: Device 0000:00:14.0 failed to suspend async: error -16
  #   PM: Some devices failed to suspend, or early wake event detected
  # Workaround by stopping bluetooth before sleep.
  file { '/etc/systemd/system/bluetooth-sleep.service':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/bluetooth/bluetooth-sleep.service',
  }

  exec { 'bluetooth-systemd-daemon-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  service { 'bluetooth-sleep':
    enable => true,
  }

  File['/etc/systemd/system/bluetooth-sleep.service']
  ~> Exec['bluetooth-systemd-daemon-reload']
  -> Service['bluetooth-sleep']
}
