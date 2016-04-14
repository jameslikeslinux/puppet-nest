class nest::profile::base::kernel {
  class use {
    @package_use { 'sys-kernel/gentoo-sources':
      use => 'symlink',
    }
  }

  include nest::profile::base::kernel::use

  package { [
    'sys-kernel/gentoo-sources',
    'sys-kernel/genkernel-next',
  ]:
    ensure => installed,
  }

  exec { 'make defconfig':
    command => '/usr/bin/make defconfig kvmconfig',
    cwd     => '/usr/src/linux',
    creates => '/usr/src/linux/.config',
    require => Package['sys-kernel/gentoo-sources'],
  }

  exec { 'make olddefconfig':
    command     => '/usr/bin/make olddefconfig',
    cwd         => '/usr/src/linux',
    refreshonly => true,
    require     => Exec['make defconfig'],
  }

  $::nest::kernel_config.each |$config, $value| {
    $line = $value ? {
      'n'     => "# ${config} is not set",
      default => "${config}=${value}",
    }

    file_line { "kernel-config-${config}-${value}":
      path    => '/usr/src/linux/.config',
      line    => $line,
      match   => "(^| )${config}[= ]",
      require => Exec['make defconfig'],
      notify  => Exec['make olddefconfig'],
    }
  }

  file { '/usr/src/linux/config':
    source  => '/usr/src/linux/.config',
    require => Exec['make olddefconfig'],
  }

  exec { 'genkernel':
    command     => 'source /etc/portage/make.conf && /usr/bin/genkernel --kernel-config=/usr/src/linux/config --makeopts="$MAKEOPTS" kernel',
    timeout     => 0,
    provider    => shell,
    refreshonly => true,
    subscribe   => File['/usr/src/linux/config'],
  }

  exec { '/usr/bin/emerge @module-rebuild':
    timeout     => 0,
    refreshonly => true,
    subscribe   => Exec['genkernel'],
  }
}
