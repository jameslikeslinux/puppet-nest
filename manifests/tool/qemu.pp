class nest::tool::qemu {
  nest::lib::package { 'app-emulation/qemu':
    ensure => installed,
    use    => [
      'static-user',
      'qemu_user_targets_arm',
      'qemu_user_targets_aarch64',
    ],
  }

  # lint:ignore:140chars
  $binfmt_conf = @(EOT)
    :qemu-arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm:OC
    :qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64:OC
    | EOT
  # lint:endignore

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
