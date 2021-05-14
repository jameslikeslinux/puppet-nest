class nest::role::workstation::ydotool {
  service { [
    'ydotoold.service',
    'ydotoold.socket',
  ]:
    ensure  => stopped,
    enable  => false,
  }
  ->
  file { [
    '/etc/systemd/system/ydotoold.service',
    '/etc/systemd/system/ydotoold.socket'
  ]:
    ensure => absent,
  }
  ~>
  ::nest::lib::systemd_reload { 'ydotool': }

  package { 'gui-apps/ydotool':
    ensure  => absent,
    require => Service['ydotoold.service'],
  }
}
