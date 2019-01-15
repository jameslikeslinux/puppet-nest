class nest::profile::workstation::cups {
  $cups_browsed_hosts = $::nest::cups_servers_hiera - "${::trusted['certname']}.nest"

  package { [
    'net-print/cups',
    'kde-apps/print-manager',
  ]:
    ensure => installed,
  }

  package { 'net-print/foomatic-db':
    ensure => absent,
  }

  file { '/etc/cups/cupsd.conf':
    mode    => '0640',
    owner   => 'root',
    group   => 'lp',
    content => template('nest/cups/cupsd.conf.erb'),
    require => Package['net-print/cups'],
    notify  => Service['cups'],
  }

  file_line { 'cups-files-system-group-wheel':
    path    => '/etc/cups/cups-files.conf',
    line    => 'SystemGroup wheel',
    match   => '^SystemGroup',
    require => Package['net-print/cups'],
    notify  => Service['cups'],
  }

  file { '/etc/cups/cups-browsed.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('nest/cups/cups-browsed.conf.erb'),
    require => Package['net-print/cups'],
    notify  => Service['cups-browsed'],
  }

  service { [
    'cups',
    'cups-browsed',
  ]:
    enable  => true,
    require => Package['net-print/cups'],
  }
}
