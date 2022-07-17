class nest::base::dracut {
  package { 'sys-kernel/dracut':
    ensure => installed,
  }

  if $facts['os']['architecture'] in ['amd64', 'x86_64'] {
    package { 'sys-firmware/intel-microcode':
      ensure => installed,
    }
  }

  if $facts['profile']['platform'] == 'live' {
    $base_config_content = @("EOT")
      add_dracutmodules+=" dmsquash-live "
      omit_dracutmodules+=" zfs "
      kernel_cmdline="rd.live.overlay.overlayfs=1"
      | EOT
  } elsif $facts['build'] and $facts['build'] != 'kernel' {
    $base_config_content = ''
  } else {
    $base_config_content = @("EOT")
      force="yes"
      hostonly="yes"
      | EOT
  }

  file { '/etc/dracut.conf.d/00-base.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $base_config_content,
    require => Package['sys-kernel/dracut'],
  }

  # Add delay to ensure all devices are enumerated at boot before the ZFS import
  # See: https://github.com/openzfs/zfs/issues/8885#issuecomment-774503341
  file_line { 'systemd-udev-settle-sleep':
    path => '/lib/systemd/system/systemd-udev-settle.service',
    line => 'ExecStartPre=/bin/sleep 5',
  }

  # XXX: Cleanup
  file_line { 'systemd-udev-trigger-changes':
    ensure => absent,
    path   => '/lib/systemd/system/systemd-udev-trigger.service',
    line   => 'ExecStart=/bin/udevadm trigger --type=devices --action=change',
  }
}
