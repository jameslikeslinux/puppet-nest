class nest::base::bootloader::systemd {
  if $facts['mountpoints']['/boot'] {
    if $facts['is_container'] or ($facts['dmi'] and $facts['dmi']['bios']['vendor'] == 'U-Boot') {
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
      command     => '/usr/bin/bootctl update --graceful --no-variables',
      refreshonly => true,
    }

    $loader_conf = @("LOADER_CONF")
      default ${facts['machine_id']}-${nest::kernel_version}.conf
      timeout 3
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
        content => "root=zfs:AUTO ${nest::base::bootloader::kernel_cmdline}\n",
        notify  => Exec['kernel-install'],
      ;
    }

    $image = $facts['os']['architecture'] ? {
      /^(amd64|x86_64)$/ => '/usr/src/linux/arch/x86/boot/bzImage',
      'armv7l'           => '/usr/src/linux/arch/arm/boot/zImage',
      'aarch64'          => '/usr/src/linux/arch/arm64/boot/Image',
    }

    exec { 'kernel-install':
      command     => "/usr/bin/kernel-install add ${nest::kernel_version} ${image}",
      refreshonly => true,
      timeout     => 0,
    }

    # Current U-Boot versions for Rock5 do not support enough EFI for systemd-boot
    if $facts['profile']['platform'] == 'rock5' {
      $extlinux_conf = @("EXTLINUX")
        DEFAULT Nest (${nest::kernel_version})
        TIMEOUT 3
        INCLUDE /extlinux/entries.conf
        | EXTLINUX

      file {
        default:
          mode  => '0755',
          owner => 'root',
          group => 'root',
        ;

        '/boot/extlinux':
          ensure => directory,
        ;

        '/boot/extlinux/extlinux.conf':
          content => $extlinux_conf,
        ;
      }

      $entries_awk = @(AWK)
        /^title\s/          { if (NR != 1) { print "" } $1 = "LABEL"; title = $0; next }
        /^version\s/        { printf "%s (%s)\n DEVICETREEDIR /\n", title, $2; next }
        /^options\s/        { $1 = " APPEND"; print; next }
        /^(linux|initrd)\s/ { printf " %s %s\n", toupper($1), $2 }
        AWK

      exec { 'generate-extlinux-entries':
        command     => "/usr/bin/awk ${entries_awk.shellquote} /boot/loader/entries/*.conf > /boot/extlinux/entries.conf",
        refreshonly => true,
        subscribe   => Exec['kernel-install'],
        require     => File['/boot/extlinux'],
        provider    => shell,
      }
    } else {
      file { '/boot/extlinux':
        ensure => absent,
        force  => true,
      }
    }
  }
}
