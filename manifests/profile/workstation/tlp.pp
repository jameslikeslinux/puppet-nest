class nest::profile::workstation::tlp {
  package { [
    'app-laptop/tlp',
    'sys-apps/ethtool',
    'sys-apps/smartmontools',
    'sys-power/acpi_call',
  ]:
    ensure => installed,
  }

  file_line { 'tlp.conf-TLP_ENABLE':
    path    => '/etc/tlp.conf',
    line    => 'TLP_ENABLE=1',
    match   => '#?TLP_ENABLE=',
    require => Package['app-laptop/tlp'],
  }

  exec {
    '/bin/systemctl mask systemd-rfkill.socket':
      creates => '/etc/systemd/system/systemd-rfkill.socket',
    ;

    '/bin/systemctl mask systemd-rfkill.service':
      creates => '/etc/systemd/system/systemd-rfkill.service',
    ;
  }

  service { [
    'tlp',
    'tlp-sleep',
  ]:
    enable  => true,
    require => Package['app-laptop/tlp'],
  }
}
