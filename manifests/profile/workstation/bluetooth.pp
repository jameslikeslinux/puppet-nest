class nest::profile::workstation::bluetooth {
  file_line { 'bluetooth-autoenable':
    path   => '/etc/bluetooth/main.conf',
    line   => 'AutoEnable=true',
    match  => '^#?AutoEnable=',
    notify => Service['bluetooth'],
  }

  service { 'bluetooth':
    enable => true,
  }

  # http://plugable.com/2014/06/23/plugable-usb-bluetooth-adapter-solving-hfphsp-profile-issues-on-linux/
  exec { 'wget-plugable-bluetooth-firmware':
    command => '/usr/bin/wget https://s3.amazonaws.com/plugable/bin/fw-0a5c_21e8.hcd -O /lib/firmware/brcm/BCM20702A1-0a5c-21e8.hcd',
    creates => '/lib/firmware/brcm/BCM20702A1-0a5c-21e8.hcd',
    require => Package['sys-kernel/linux-firmware'],
  }

  $systemd_dropin_content = @(DROPIN)
    [Unit]
    Conflicts=bluetooth.service
    | DROPIN

  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root',
    ;

    '/etc/systemd/system/sleep.target.d':
      ensure => directory,
    ;

    '/etc/systemd/system/sleep.target.d/bluetooth-conflict.conf':
      content => $systemd_dropin_content,
      notify  => Exec['bluetooth-systemd-daemon-reload'],
    ;
  }

  exec { 'bluetooth-systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }
}
