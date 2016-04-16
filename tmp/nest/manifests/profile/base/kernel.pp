class nest::profile::base::kernel {
  class use {
    package_use { 'sys-kernel/gentoo-sources':
      use => 'symlink',
    }
  }

  include '::nest::profile::base::kernel::use'

  package { 'sys-kernel/gentoo-sources':
    ensure => installed,
  }

  exec { 'make defconfig':
    command => '/usr/bin/make defconfig kvmconfig',
    cwd     => '/usr/src/linux',
    creates => '/usr/src/linux/.config',
    require => Package['sys-kernel/gentoo-sources'],
  }

  $::nest::kernel_config.each |$config, $value| {
    nest::kernel::config { $config:
      value   => $value,
      require => Exec['make defconfig'],
      notify  => Exec['make kernel'],
    }
  }

  include '::nest::profile::setup::portage'
  exec { 'make kernel':
    command     => "/usr/bin/make ${::nest::profile::setup::portage::makeopts} clean olddefconfig all install modules_install",
    cwd         => '/usr/src/linux',
    timeout     => 0,
    refreshonly => true,
  }

  exec { '/usr/bin/emerge @module-rebuild':
    timeout     => 0,
    refreshonly => true,
    subscribe   => Exec['make kernel'],
  }
}
