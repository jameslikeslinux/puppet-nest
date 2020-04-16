class nest::profile::base::kernel {
  file { '/etc/portage/patches/sys-kernel':
    ensure  => absent,
    recurse => true,
    force   => true,
    before  => Package['sys-kernel/gentoo-sources'],
  }

  nest::lib::portage::package_use { 'sys-kernel/gentoo-sources':
    use => 'symlink',
  }

  package { 'app-admin/eclean-kernel':
    ensure => absent,
  }

  package { [
    'sys-kernel/gentoo-sources',
    'sys-kernel/linux-firmware',
  ]:
    ensure => installed,
  }

  if $nest and $nest['profile'] == 'beaglebone' {
    $defconfig = 'multi_v7_defconfig'
  } else {
    $defconfig = 'defconfig kvmconfig'
  }

  exec { 'make defconfig':
    command => "/usr/bin/make ${defconfig}",
    cwd     => '/usr/src/linux',
    creates => '/usr/src/linux/.config',
    require => Package['sys-kernel/gentoo-sources'],
    notify  => Exec['make kernel'],
  }

  $::nest::lib::kernel_config_hiera.each |$config, $value| {
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

  include '::nest::profile::base::portage'
  exec { 'make kernel':
    command     => "/usr/bin/make ${::nest::profile::base::portage::makeopts} clean olddefconfig all ${install_target} modules_install",
    cwd         => '/usr/src/linux',
    path        => ['/usr/lib/distcc/bin', '/usr/bin', '/bin'],
    environment => 'HOME=/root',  # for distcc
    timeout     => 0,
    refreshonly => true,
  }

  exec { 'module-rebuild':
    command     => "/usr/bin/emerge --usepkg n --jobs ${::nest::profile::base::portage::loadlimit} --load-average ${::nest::profile::base::portage::loadlimit} @module-rebuild",
    timeout     => 0,
    refreshonly => true,
    subscribe   => Exec['make kernel'],
  }
}
