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

  # During boot, systemd-udev-trigger -> systemd-udev-settle ->
  # zfs-import-cache, but for some reason, persistent device labels aren't
  # processed in time by the trigger-settle loop.  Triggering changes seems to
  # fix the problem.
  file_line { 'systemd-udev-trigger-changes':
    path  => '/lib/systemd/system/systemd-udev-trigger.service',
    after => 'ExecStart=/bin/udevadm trigger --type=devices --action=add',
    line  => 'ExecStart=/bin/udevadm trigger --type=devices --action=change',
  }
}
