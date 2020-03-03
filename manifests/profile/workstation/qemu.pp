class nest::profile::workstation::qemu {
  nest::portage::package_use { 'app-emulation/qemu':
    use => ['spice', 'usbredir', 'static-user', 'qemu_user_targets_arm'],
  }

  package { 'app-emulation/qemu':
    ensure => installed,
  }

  $binfmt_conf = @(EOT)
    :qemu-arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm:OC
    | EOT

  file { '/etc/binfmt.d/qemu.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $binfmt_conf,
    notify  => Service['systemd-binfmt'],
    require => Package['app-emulation/qemu'],
  }

  service { 'systemd-binfmt':
    ensure => running,
  }
}
