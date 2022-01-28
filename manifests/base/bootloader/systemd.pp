class nest::base::bootloader::systemd {
  if $facts['mountpoints']['/boot'] {
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
      command     => '/usr/bin/bootctl update --no-variables',
      refreshonly => true,
    }

    $loader_conf = @("LOADER_CONF")
      default ${facts['machine_id']}-*
      | LOADER_CONF

    file { '/boot/loader/loader.conf':
      content => $loader_conf,
      require => Exec['bootctl-install'],
    }

    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      "/boot/${facts['machine_id']}":
        ensure => directory,
        before => Exec['kernel-install'],
      ;

      '/etc/kernel':
        ensure => directory,
      ;

      '/etc/kernel/cmdline':
        content => "root=zfs:AUTO ${::nest::base::bootloader::kernel_cmdline}\n",
        notify  => Exec['kernel-install'],
      ;
    }

    $image = $facts['os']['architecture'] ? {
      'amd64'   => '/usr/src/linux/arch/x86/boot/bzImage',
      'armv7l'  => '/usr/src/linux/arch/arm/boot/zImage',
      'aarch64' => '/usr/src/linux/arch/arm64/boot/Image',
    }

    exec { 'kernel-install':
      command     => "version=\$(ls /lib/modules | sort -V | tail -1) && kernel-install add \$version ${image}",
      provider    => shell,
      refreshonly => true,
      timeout     => 0,
    }
  }
}
