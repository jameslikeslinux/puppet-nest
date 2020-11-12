class nest::base::zram {
  file { '/etc/modules-load.d/zram.conf':
    ensure => absent,
  }

  file { '/etc/udev/rules.d/10-zram.rules':
    ensure => absent,
  }

  file { '/etc/dracut.conf.d/10-zram.conf':
    ensure  => absent,
    require => Class['nest::base::dracut'],
    notify  => Class['nest::base::bootloader'],
  }

  sysctl { 'vm.swappiness':
    ensure => absent,
    value  => '100',
    target => '/etc/sysctl.d/zram.conf',
  }
}
