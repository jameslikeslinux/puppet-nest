class nest::base::kexec {
  if $nest::kexec {
    # For kernel_cmdline
    include nest::base::bootloader

    nest::lib::package { 'sys-apps/kexec-tools':
      ensure => installed,
    }

    case $nest::bootloader {
      'grub': {
        $image  = "/boot/vmlinuz-${nest::kernel_version}"
        $initrd = "/boot/initramfs-${nest::kernel_version}.img"
      }

      'systemd': {
        $image  = "/boot/${facts['machine_id']}/${nest::kernel_version}/linux"
        $initrd = "/boot/${facts['machine_id']}/${nest::kernel_version}/initrd"
      }

      default: {
        fail("Unhandled support for kexec with ${nest::bootloader} bootloader")
      }
    }

    $kexec_load_env = @("ENV")
      IMAGE=${image}
      INITRD=${initrd}
      KERNEL_CMDLINE="root=zfs:AUTO ${nest::base::bootloader::kernel_cmdline}"
      | ENV

    file { '/etc/default/kexec-load':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $kexec_load_env,
      notify  => Service['kexec-load'],
    }

    $kexec_load_ensure = $facts['is_container'] ? {
      true    => undef,
      default => running,
    }

    file { '/etc/systemd/system/kexec-load.service':
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/nest/kexec/kexec-load.service',
    }
    ~>
    nest::lib::systemd_reload { 'kexec': }
    ~>
    service { 'kexec-load':
      ensure    => $kexec_load_ensure,
      enable    => true,
      subscribe => Class['nest::base::bootloader'],
    }
  } else {
    service { 'kexec-load':
      ensure => stopped,
      enable => false,
    }
    ->
    file { [
      '/etc/default/kexec-load',
      '/etc/systemd/system/kexec-load.service',
    ]:
      ensure => absent,
    }
    ~>
    nest::lib::systemd_reload { 'kexec': }

    nest::lib::package { 'sys-apps/kexec-tools':
      ensure  => absent,
      require => Service['kexec-load'],
    }
  }
}
