class nest::base::kernel {
  # For nest::base::portage::makeopts
  include '::nest::base::portage'

  Nest::Lib::Kconfig {
    config => '/usr/src/linux/.config',
  }

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
    'sopine'          => 'defconfig',
    default           => 'defconfig kvm_guest.config',
  }

  exec { 'kernel-defconfig':
    command => "/usr/bin/make ${defconfig}",
    cwd     => '/usr/src/linux',
    creates => '/usr/src/linux/.config',
    require => Package[$sources_package],
    notify  => Exec['kernel-build'],
  }

  $::nest::kernel_config.each |$config, $value| {
    nest::lib::kconfig { $config:
      value => $value,
    }
  }

  if $::nest::bootloader == 'systemd' {
    nest::lib::kconfig { 'CONFIG_EFI_STUB':
      value => y,
    }
  }

  # Workaround https://sourceware.org/bugzilla/show_bug.cgi?id=26256
  if $facts['profile']['platform'] == 'raspberrypi' {
    $lld_override = 'LD=ld.lld'

    Package_env <| title == 'sys-fs/zfs-kmod' |> {
      env +> 'lld.conf',
    }
  }

  exec { 'kernel-olddefconfig':
    command     => '/usr/bin/make olddefconfig',
    cwd         => '/usr/src/linux',
    refreshonly => true,
  }
  ~>
  exec { 'kernel-build':
    command     => "/usr/bin/make ${::nest::base::portage::makeopts} ${lld_override} olddefconfig all modules_install 2>&1 | /usr/bin/tee build.log",
    cwd         => '/usr/src/linux',
    path        => ['/usr/lib/distcc/bin', '/usr/bin', '/bin'],
    environment => 'HOME=/root',  # for distcc
    timeout     => 0,
    refreshonly => true,
    noop        => !$facts['build'],
  }
  ~>
  exec { 'module-rebuild':
    command     => "/usr/bin/emerge --buildpkg n --usepkg n @module-rebuild",
    timeout     => 0,
    refreshonly => true,
  }
  ->
  nest::lib::package { 'sys-fs/zfs-kmod':
    ensure => installed,
    binpkg => false,
  }

  Exec['kernel-defconfig']
  -> Nest::Lib::Kconfig <| config == '/usr/src/linux/.config' |>
  ~> Exec['kernel-olddefconfig']
}
