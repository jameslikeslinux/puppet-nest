class nest::profile::base::kernel {
  nest::portage::package_use { 'sys-kernel/gentoo-sources':
    use => 'symlink',
  }

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
    if is_numeric($value) {
      $line = "${config}=${value}"
    } else {
      $line = $value ? {
        'n'       => "# ${config} is not set",
        /^(y|m)$/ => "${config}=${value}",
        default   => "${config}=\"${value}\"",
      }
    }

    file_line { "kernel-config-${config}-${value}":
      path    => '/usr/src/linux/.config',
      line    => $line,
      match   => "(^| )${config}[= ]",
      require => Exec['make defconfig'],
      notify  => Exec['make kernel'],
    }
  }

  include '::nest::profile::base::portage'
  exec { 'make kernel':
    command     => "/usr/bin/make ${::nest::profile::base::portage::makeopts} clean olddefconfig all install modules_install",
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
