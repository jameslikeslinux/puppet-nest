class nest::base::dracut {
  package { 'sys-kernel/dracut':
    ensure => installed,
  }

  if $facts['os']['architecture'] == 'amd64' {
    package { 'sys-firmware/intel-microcode':
      ensure => installed,
    }

    $early_microcode = 'yes'
  } else {
    $early_microcode = 'no'
  }

  if $facts['live'] {
    $base_config_content = @(EOT)
      add_dracutmodules+=" dmsquash-live livenet "
      omit_dracutmodules+=" zfs "
      kernel_cmdline="rd.live.overlay.thin=1 rd.vconsole.font=ter-v16b"
      | EOT
  } else {
    $base_config_content = @("EOT")
      early_microcode="${early_microcode}"
      hostonly="yes"
      hostonly_cmdline="no"
      force="yes"
      | EOT
  }

  file { '/etc/dracut.conf.d/00-base.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $base_config_content,
    require => Package['sys-kernel/dracut'],
  }

  $add_drivers = $::platform ? {
    'beagleboneblack' => 'tda998x tilcdc',
    'pinebookpro'     => 'rockchipdrm',
    default           => undef,
  }

  $drivers_ensure = $add_drivers ? {
    undef   => absent,
    default => present,
  }

  $drivers_config_content = @("DRIVERS_CONF")
    add_drivers+=\" ${add_drivers} \"
    | DRIVERS_CONF

  file { '/etc/dracut.conf.d/10-drivers.conf':
    ensure  => $drivers_ensure,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $drivers_config_content,
    require => Package['sys-kernel/dracut'],
  }
}
