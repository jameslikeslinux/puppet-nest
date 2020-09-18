class nest::role::workstation::ydotool {
  package { 'gui-apps/ydotool':
    ensure => installed,
  }

  file {
    default:
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      notify => Nest::Lib::Systemd_reload['ydotool'],
    ;

    '/etc/systemd/system/ydotoold.service':
      source => 'puppet:///modules/nest/ydotool/ydotoold.service',
    ;

    '/etc/systemd/system/ydotoold.socket':
      source => 'puppet:///modules/nest/ydotool/ydotoold.socket',
    ;
  }

  ::nest::lib::systemd_reload { 'ydotool': }

  service { 'ydotoold':
    enable  => true,
    require => Nest::Lib::Systemd_reload['ydotool'],
  }
}
