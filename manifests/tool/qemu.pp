class nest::tool::qemu (
  Array[String] $user_targets = [],
) {
  # Avoid conflicts with volume-mapped /usr/bin/qemu-* user binaries
  unless $facts['is_container'] {
    nest::lib::package { 'app-emulation/qemu':
      ensure => installed,
      use    => ['static-user'] + $user_targets.map |$arch| { "qemu_user_targets_${arch}" },
    }
    ->
    file { '/etc/binfmt.d/qemu.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => epp('nest/qemu/binfmt.conf.epp'),
    }
    ~>
    service { 'systemd-binfmt':
      ensure => running,
    }
  }
}
