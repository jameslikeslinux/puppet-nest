class nest::base::bootloader::grub {
  nest::lib::package_use { 'sys-boot/grub':
    use => ['grub_platforms_efi-64', 'grub_platforms_pc', 'libzfs', 'truetype'],
  }

  package { 'sys-boot/grub':
    ensure => installed,
  }

  if $facts['mountpoints']['/boot'] or ($facts['profile']['platform'] == 'live' and $facts['is_container'] and !$facts['build']) {
    file { '/boot/grub':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    file { [
      '/boot/grub/fonts',
      '/boot/grub/layouts',
    ]:
      ensure  => directory,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      recurse => true,
      purge   => true,
    }

    $font = "ter-x${::nest::console_font_size}b"

    exec { 'grub-mkfont':
      command => "/usr/bin/grub-mkfont -o /boot/grub/fonts/${font}.pf2 /usr/share/fonts/terminus/${font}.pcf.gz",
      creates => "/boot/grub/fonts/${font}.pf2",
      require => [
        Package['sys-boot/grub'],
        File['/boot/grub/fonts'],
      ],
    }

    file { "/boot/grub/fonts/${font}.pf2":
      require => Exec['grub-mkfont'],
    }

    file { '/boot/grub/layouts/dvorak.gkb':
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/nest/keymaps/dvorak.gkb',
    }

    $dracut_script = @(DRACUT_SCRIPT)
      version=$(ls /lib/modules | sort -V | tail -1) &&
      dracut --force --kver $version &&
      chmod 644 /boot/initramfs-${version}.img
      | DRACUT_SCRIPT

    # Install stuff normally handled by kernel-install(8)
    exec {
      default:
        refreshonly => true,
        subscribe   => File['/boot/grub']
      ;

      'kernel-install':
        command => '/usr/bin/make install',
        cwd     => '/usr/src/linux',
      ;

      'dracut':
        command  => $dracut_script,
        provider => shell,
      ;
    }
    ~>
    exec { 'grub-mkconfig':
      command     => '/usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg',
      refreshonly => true,
      require     => Exec['grub-mkfont'],
    }

    if $facts['profile']['platform'] == 'live' {
      exec { 'grub-modify-live-config':
        command     => '/bin/sed -i -r "/insmod ext2/,/search/d" /boot/grub/grub.cfg',
        refreshonly => true,
        subscribe   => Exec['grub-mkconfig'],
      }
    }

    File_line {
      path    => '/etc/default/grub',
      require => Package['sys-boot/grub'],
      notify  => Exec['grub-mkconfig'],
    }

    file_line { 'grub-set-kernel-cmdline':
      line  => "GRUB_CMDLINE_LINUX=\"${::nest::base::bootloader::kernel_cmdline}\"",
      match => '^#?GRUB_CMDLINE_LINUX=',
    }

    if $facts['profile']['platform'] or $facts['virtual'] == 'kvm' {
      $gfxmode    = 'GRUB_GFXMODE=1024x768'
      $gfxpayload = 'GRUB_GFXPAYLOAD_LINUX=keep'
    } else {
      $gfxmode    = '#GRUB_GFXMODE=640x480'
      $gfxpayload = '#GRUB_GFXPAYLOAD_LINUX='
    }

    file_line { 'grub-set-gfxmode':
      line  => $gfxmode,
      match => '^#?GRUB_GFXMODE',
    }

    file_line { 'grub-set-gfxpayload':
      line  => $gfxpayload,
      match => '^#?GRUB_GFXPAYLOAD_LINUX',
    }

    file_line { 'grub-disable-linux-uuid':
      line  => 'GRUB_DISABLE_LINUX_UUID=true',
      match => '^#?GRUB_DISABLE_LINUX_UUID=',
    }

    $grub_device = $facts['profile']['platform'] == 'live' ? {
      true    => "live:LABEL=${trusted['certname'].upcase}",
      default => 'zfs:AUTO',
    }

    file_line { 'grub-set-device':
      line  => "GRUB_DEVICE=${grub_device}",
      match => '^#?GRUB_DEVICE=',
    }

    file_line { 'grub-set-fs':
      line  => 'GRUB_FS=',
      match => '^#?GRUB_FS=',
    }

    file_line { 'grub-set-font':
      line  => "GRUB_FONT=/boot/grub/fonts/${font}.pf2",
      match => '^#?GRUB_FONT=',
    }

    $::partitions.each |$partition, $attributes| {
      $disk = regsubst($partition, 'p?(art)?\d+$', '')

      if "${::trusted['certname']}-" in $attributes['partlabel'] {
        $grub_install_command = $attributes['partlabel'] ? {
          /-efi/  => "/bin/mkdir /boot/efi && /bin/mount ${partition} /boot/efi && /usr/sbin/grub-install --target=x86_64-efi --removable --modules=part_gpt && /bin/umount /boot/efi && /bin/rm -rf /boot/efi",
          /-bios/ => "/usr/sbin/grub-install --target=i386-pc --modules=part_gpt ${disk}",
          default => undef,
        }

        if $grub_install_command {
          exec { "grub-install-${disk}":
            command     => $grub_install_command,
            refreshonly => true,
            require     => Package['sys-boot/grub'],
            before      => File['/boot/grub'],
          }
        }
      }
    }
  }
}
