class nest::profile::workstation::tlp {
  package { [
    'app-laptop/tlp',
    'sys-apps/ethtool',
    'sys-apps/smartmontools',
    'sys-power/acpi_call',
  ]:
    ensure => installed,
  }

  file_line {
    default:
      path    => '/etc/tlp.conf',
      require => Package['app-laptop/tlp'],
    ;

    'tlp.conf-TLP_ENABLE':
      line  => 'TLP_ENABLE=1',
      match => '#?TLP_ENABLE=',
    ;

    'tlp.conf-DISK_DEVICES':
      line  => "DISK_DEVICES=\"${facts['disks'].keys.join(' ')}\"",
      match => '#?DISK_DEVICES=',
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
