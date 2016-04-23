class nest::profile::base::grub {
  nest::portage::package_use { 'sys-boot/grub':
    use => ['grub_platforms_efi-64', 'grub_platforms_pc', 'libzfs'],
  }

  package { 'sys-boot/grub':
    ensure => installed,
  }

  File_line {
    require => Package['sys-boot/grub'],
    notify  => Exec['grub2-mkconfig'],
  }

  $kernel_cmdline = strip("init=/usr/lib/systemd/systemd quiet splash ${::nest::kernel_cmdline}")
  file_line { 'grub-set-kernel-cmdline':
    path    => '/etc/default/grub',
    line    => "GRUB_CMDLINE_LINUX=\"${kernel_cmdline}\"",
    match   => '^#?GRUB_CMDLINE_LINUX=',
  }

  file_line { 'grub-set-device':
    path  => '/etc/default/grub',
    line  => 'GRUB_DEVICE=',
    match => '^#?GRUB_DEVICE=',
  }

  $::nest::grub_disks.each |$grub_disk| {
    $install_command = $grub_disk ? {
      /p(art)?\d$/ => "/bin/mkdir /boot/efi && /bin/mount ${grub_disk} /boot/efi && /usr/sbin/grub2-install --target=x86_64-efi --removable --modules=part_gpt && /bin/umount /boot/efi && /bin/rm -rf /boot/efi",
      default      => "/usr/sbin/grub2-install --target=i386-pc ${grub_disk}",
    }

    exec { "grub-install-${grub_disk}":
      command     => $install_command,
      refreshonly => true,
      require     => Package['sys-boot/grub'],
      before      => Exec['grub2-mkconfig'],
    }
  }

  exec { 'grub2-mkconfig':
    command     => '/usr/sbin/grub2-mkconfig -o /boot/grub/grub.cfg',
    refreshonly => true,
  }
}
