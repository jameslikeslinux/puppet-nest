class nest::base::dracut {
  if $facts['force_kernel_install'] {
    notify { 'forcing-kernel-install': }
  }

  package { 'sys-kernel/dracut':
    ensure => installed,
  }

  File {
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => Package['sys-kernel/dracut'],
  }

  if $facts['os']['architecture'] in ['amd64', 'x86_64'] {
    package { 'sys-firmware/intel-microcode':
      ensure => installed,
    }
  }

  if $facts['profile']['platform'] == 'live' {
    $base_config_content = @(EOT)
      add_dracutmodules+=" dmsquash-live "
      omit_dracutmodules+=" zfs "
      kernel_cmdline="rd.live.overlay.overlayfs=1"
      | EOT
  } elsif $facts['build'] and $facts['build'] != 'kernel' {
    $base_config_content = ''
  } else {
    $base_config_content = @(EOT)
      force="yes"
      hostonly="yes"
      | EOT
  }

  file { '/etc/dracut.conf.d/00-base.conf':
    content => $base_config_content,
  }

  $force_drivers = $facts['profile']['platform'] ? {
    'raspberrypi' => ['vc4'],
    default       => undef,
  }

  if $force_drivers {
    file { '/etc/dracut.conf.d/10-drivers.conf':
      content => "force_drivers+=\" ${force_drivers.join(' ')} \"\n",
    }
  } else {
    file { '/etc/dracut.conf.d/10-drivers.conf':
      ensure => absent,
    }
  }

  # Add delay to ensure all devices are enumerated at boot before the ZFS import
  # See: https://github.com/openzfs/zfs/issues/8885#issuecomment-774503341
  $systemd_udev_settle_sleep = @(END_DROPIN)
    [Service]
    ExecStartPre=/bin/sleep 5
    | END_DROPIN
  $install_config = @(END_CONF)
    install_items+=" /etc/systemd/system/systemd-udev-settle.service.d/10-sleep.conf "
    | END_CONF

  file {
    '/etc/systemd/system/systemd-udev-settle.service.d':
      ensure => directory,
    ;

    '/etc/systemd/system/systemd-udev-settle.service.d/10-sleep.conf':
      content => $systemd_udev_settle_sleep,
      notify  => Nest::Lib::Systemd_reload['dracut'],
    ;

    '/etc/dracut.conf.d/10-systemd.conf':
      content => $install_config,
    ;
  }

  nest::lib::systemd_reload { 'dracut': }

  # XXX: Cleanup
  file_line {
    default:
      ensure => absent,
    ;

    'systemd-udev-settle-sleep':
      path => '/lib/systemd/system/systemd-udev-settle.service',
      line => 'ExecStartPre=/bin/sleep 5',
    ;

    'systemd-udev-trigger-changes':
      path => '/lib/systemd/system/systemd-udev-trigger.service',
      line => 'ExecStart=/bin/udevadm trigger --type=devices --action=change',
    ;
  }
}
