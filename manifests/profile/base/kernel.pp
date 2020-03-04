class nest::profile::base::kernel {
  unless $nest and $nest['profile'] == 'beaglebone' {
  file {
    default:
      ensure => directory,
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
    ;

    '/etc/portage/patches/sys-kernel':
    ;

    '/etc/portage/patches/sys-kernel/gentoo-sources':
      source  => 'puppet:///modules/nest/kernel/patches/',
      recurse => true,
      purge   => true,
      before  => Package['sys-kernel/gentoo-sources'],
    ;
  }

  nest::portage::package_use { 'sys-kernel/gentoo-sources':
    use => 'symlink',
  }

  package { [
    'app-admin/eclean-kernel',
    'sys-kernel/gentoo-sources',
    'sys-kernel/linux-firmware',
  ]:
    ensure => installed,
  }

  exec { 'make defconfig':
    command => '/usr/bin/make defconfig kvmconfig',
    cwd     => '/usr/src/linux',
    creates => '/usr/src/linux/.config',
    require => Package['sys-kernel/gentoo-sources'],
  }

  $::nest::kernel_config_hiera.each |$config, $value| {
    nest::kernel_config { $config:
      value => $value,
    }
  }

  if $::nest::bootloader == 'systemd' {
    nest::kernel_config { 'CONFIG_EFI_STUB':
      value => 'y',
    }

    # Use kernel-install(8) instead
    $install_target = ''
  } else {
    $install_target = 'install'
  }

  include '::nest::profile::base::portage'
  exec { 'make kernel':
    command     => "/usr/bin/make CC=/usr/lib/distcc/bin/gcc ${::nest::profile::base::portage::makeopts} clean olddefconfig all ${install_target} modules_install",
    cwd         => '/usr/src/linux',
    environment => 'HOME=/var/tmp/portage/.distcc',
    timeout     => 0,
    refreshonly => true,
  }

  exec { 'module-rebuild':
    command     => "/usr/bin/emerge --usepkg n --jobs ${::nest::profile::base::portage::loadlimit} --load-average ${::nest::profile::base::portage::loadlimit} @module-rebuild",
    timeout     => 0,
    refreshonly => true,
    subscribe   => Exec['make kernel'],
  }

  exec { '/usr/bin/eclean-kernel --destructive -n 2':
    refreshonly => true,
    subscribe   => Exec['module-rebuild'],
    require     => Package['app-admin/eclean-kernel'],
  }
  }
}
