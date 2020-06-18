class nest::base::zram {
  $zram_disksize = $facts['memory']['system']['total_bytes'] * 2

  file { '/etc/modules-load.d/zram.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "zram\n",
  }

  file { '/etc/udev/rules.d/10-zram.rules':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "KERNEL==\"zram0\", ATTR{disksize}=\"${zram_disksize}\"\n",
  }

  # Move pages to zram more opportunistically
  sysctl { 'vm.swappiness':
    value  => '100',
    target => '/etc/sysctl.d/zram.conf',
  }
}
