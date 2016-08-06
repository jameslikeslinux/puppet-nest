class nest::profile::workstation::cups {
  package { [
    'net-print/cups',
    'net-print/foomatic-db',
    'kde-apps/print-manager',
  ]:
    ensure => installed,
  }

  file_line { 'cups-files-system-group-wheel':
    path    => '/etc/cups/cups-files.conf',
    line    => 'SystemGroup wheel',
    match   => '^SystemGroup',
    require => Package['net-print/cups'],
    notify  => Service['cups'],
  }

  service { [
    'cups',
    'cups-browsed',
  ]:
    enable  => true,
    require => Package['net-print/cups'],
  }
}
