class nest::profile::workstation::cups {
  $cups_browsed_changes = ($::nest::cups_servers_hiera - "${::trusted['certname']}.nest").map |$server| {
    [
      'set directive[last() + 1] BrowsePoll',
      "set directive[. = 'BrowsePoll'][last()]/arg ${server}",
    ]
  }.flatten

  package { [
    'net-print/cups',
    'kde-apps/print-manager',
  ]:
    ensure => installed,
  }

  package { 'net-print/foomatic-db':
    ensure => absent,
  }

  file_line { 'cups-files-system-group-wheel':
    path    => '/etc/cups/cups-files.conf',
    line    => 'SystemGroup wheel',
    match   => '^SystemGroup',
    require => Package['net-print/cups'],
    notify  => Service['cups.service'],
  }

  augeas { 'cups-browsed-browse-poll':
    context => '/files/etc/cups/cups-browsed.conf',
    changes => ['rm directive[. = \'BrowsePoll\']'] + $cups_browsed_changes,
    require => Package['net-print/cups'],
    notify  => Service['cups-browsed'],
  }

  service { [
    'cups.service',
    'cups-browsed',
  ]:
    enable  => true,
    require => Package['net-print/cups'],
  }
}
