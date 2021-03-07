class nest::base::bootloader::systemd {
  case $facts['os']['architecture'] {
    'amd64': {
      $boot_efi = 'bootx64.efi'
      $image    = '/usr/src/linux/arch/x86/boot/bzImage'
    }

    'aarch64': {
      $boot_efi = 'bootaa64.efi'
      $image    = '/usr/src/linux/arch/arm64/boot/Image'
    }

    'armv7l': {
      $boot_efi = 'bootarm.efi'
      $image    = '/usr/src/linux/arch/arm/boot/zImage'
    }
  }

  if $mountpoints['/boot'] {
    if $facts['is_container'] or $facts['dmi']['bios']['vendor'] == 'U-Boot' {
      $bootctl_args = '--no-variables'
    } else {
      $bootctl_args = ''
    }

    exec { 'bootctl-install':
      command => "/usr/bin/bootctl install --graceful ${bootctl_args}",
      unless  => '/usr/bin/bootctl is-installed | /bin/grep yes',
      before  => Exec['kernel-install'],
    }
    ~>
    exec { 'bootctl-update':
      command     => "/usr/bin/bootctl update --no-variables",
      refreshonly => true,
    }
  } else {
    file {
      default:
        mode  => '0755',
        owner => 'root',
        group => 'root',
      ;

      [
        '/boot/EFI',
        '/boot/EFI/BOOT',
      ]:
        ensure => directory,
      ;

      "/boot/EFI/BOOT/${boot_efi.upcase}":
        source => "/usr/lib/systemd/boot/efi/systemd-${boot_efi}",
      ;

      "/boot/${facts['machine_id']}":
        ensure => directory,
        before => Exec['kernel-install'],
      ;
    }

    exec { 'kernel-install-fix-boot-path':
      command     => '/bin/sed -i "s@/boot/@//@g" /boot/loader/entries/*.conf',
      provider    => shell,
      refreshonly => true,
      subscribe   => Exec['kernel-install'],
    }
  }

  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root',
    ;

    '/etc/kernel':
      ensure => directory,
    ;

    '/etc/kernel/cmdline':
      content => "root=zfs:AUTO ${::nest::base::bootloader::kernel_cmdline}\n",
      notify  => Exec['kernel-install'],
    ;
  }

  exec { 'kernel-install':
    command     => "version=\$(ls /lib/modules | sort -V | tail -1) && kernel-install add \$version ${image}",
    provider    => shell,
    refreshonly => true,
  }
}
