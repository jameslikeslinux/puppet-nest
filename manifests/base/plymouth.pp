class nest::base::plymouth {
  nest::lib::package_use { 'sys-boot/plymouth':
    use => '-pango',
  }

  package { 'sys-boot/plymouth':
    ensure => installed,
  }

  # Plymouth tries to start systemd-vconsole-setup before the console is ready,
  # resulting in I/O error when trying to start the service.
  file_line { 'plymouth-start.service-Wants':
    path    => '/lib/systemd/system/plymouth-start.service',
    line    => 'Wants=systemd-ask-password-plymouth.path',
    match   => '^Wants=',
    require => Package['sys-boot/plymouth'],
    notify  => Class['nest::base::dracut'],
  }

  $plymouthd_conf_contents = @(PLYMOUTH_CONF)
    [Daemon]
    Theme=details
    | PLYMOUTH_CONF

  file { '/etc/plymouth/plymouthd.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $plymouthd_conf_contents,
    require => Package['sys-boot/plymouth'],
    notify  => Class['nest::base::dracut'],
  }
}
