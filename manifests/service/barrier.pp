class nest::service::barrier {
  package { 'x11-misc/barrier':
    ensure => installed,
  }

  # barrier pulls in avahi, which I don't want, and it gets started by
  # cups-browsed.service.  Mask it:
  file { [
    '/etc/systemd/system/avahi-daemon.service',
    '/etc/systemd/system/avahi-daemon.socket',
  ]:
    ensure  => link,
    target  => '/dev/null',
    require => Package['x11-misc/barrier'],
    notify  => Nest::Lib::Systemd_reload['barrier'],
  }

  ::nest::lib::systemd_reload { 'barrier': }

  firewall { '100 barrier':
    proto   => tcp,
    dport   => 24800,
    iniface => 'virbr0',
    state   => 'NEW',
    action  => accept,
  }
}
