class nest::tool::qemu {
  # Avoid conflicts with volume-mapped /usr/bin/qemu-* user binaries
  unless $facts['is_container'] {
    nest::lib::package { 'app-emulation/qemu':
      ensure => installed,
      use    => [
        'static-user',
        'qemu_user_targets_arm',
        'qemu_user_targets_aarch64',
        'qemu_user_targets_riscv64',
        'qemu_user_targets_x86_64',
      ],
    }
    ->
    file { '/etc/binfmt.d/qemu.conf':
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/nest/qemu/binfmt.conf',
    }
    ~>
    service { 'systemd-binfmt':
      ensure => running,
    }
  }
}
