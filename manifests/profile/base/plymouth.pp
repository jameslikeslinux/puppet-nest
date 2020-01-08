class nest::profile::base::plymouth {
  file { [
    '/etc/portage/patches/sys-boot',
    '/etc/portage/patches/sys-boot/plymouth',
  ]:
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  file { '/etc/portage/patches/sys-boot/plymouth/plymouth-details-theme-improve-password-prompt.patch':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/plymouth/plymouth-details-theme-improve-password-prompt.patch',
    before => Package['sys-boot/plymouth'],
  }

  package { 'sys-boot/plymouth':
    ensure => installed,
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
  }
}
