class nest::service::barrier {
  nest::lib::package { 'x11-misc/barrier':
    ensure => installed,
    use    => '-gui',
  }

  firewalld_service { 'synergy':
    ensure => present,
    zone   => 'libvirt',
  }

  # XXX: Cleanup from previous dependency on avahi
  file { [
    '/etc/systemd/system/avahi-daemon.service',
    '/etc/systemd/system/avahi-daemon.socket',
  ]:
    ensure => absent,
    notify => Nest::Lib::Systemd_reload['barrier'],
  }

  ::nest::lib::systemd_reload { 'barrier': }
}
