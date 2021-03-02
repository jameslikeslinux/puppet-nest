class nest::base::kernel {
  $sources_package = $facts['profile']['platform'] ? {
    'raspberrypi' => 'sys-kernel/raspberrypi-sources',
    default       => 'sys-kernel/gentoo-sources',
  }

  nest::lib::package_use { $sources_package:
    use => 'symlink',
  }

  package { $sources_package:
    ensure => installed,
  }

  $defconfig = $facts['profile']['platform'] ? {
    'beagleboneblack' => 'multi_v7_defconfig',
    'pinebookpro'     => 'defconfig',
    'raspberrypi'     => 'bcm2711_defconfig',
    default           => 'defconfig kvmconfig',
  }

  exec { 'make defconfig':
    command => "/usr/bin/make ${defconfig}",
    cwd     => '/usr/src/linux',
    creates => '/usr/src/linux/.config',
    require => Package[$sources_package],
    notify  => Exec['make kernel'],
  }

  $::nest::kernel_config.each |$config, $value| {
    nest::lib::kernel_config { $config:
      value => $value,
    }
  }

  if $::nest::bootloader == 'systemd' {
    nest::lib::kernel_config { 'CONFIG_EFI_STUB':
      value => 'y',
    }

    # Use kernel-install(8) instead
    $install_target = ''
  } else {
    $install_target = 'install'
  }

  include '::nest::base::portage'
  exec { 'make kernel':
    command     => "/usr/bin/make ${::nest::base::portage::makeopts} olddefconfig all ${install_target} modules_install | /usr/bin/tee build.log",
    cwd         => '/usr/src/linux',
    path        => ['/usr/lib/distcc/bin', '/usr/bin', '/bin'],
    environment => 'HOME=/root',  # for distcc
    timeout     => 0,
    refreshonly => true,
  }

  exec { 'module-rebuild':
    command     => "/usr/bin/emerge --oneshot --usepkg n --jobs ${::nest::concurrency} --load-average ${::nest::base::portage::loadlimit} zfs-kmod",
    timeout     => 0,
    refreshonly => true,
    subscribe   => Exec['make kernel'],
  }
}
