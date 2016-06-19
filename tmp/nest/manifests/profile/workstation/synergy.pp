class nest::profile::workstation::synergy {
  nest::portage::package_use { 'x11-misc/synergy':
    use => '-qt4',
  }

  package { 'x11-misc/synergy':
    ensure => installed,
  }

  file { '/etc/synergy.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $::nest::synergy_config,
    require => Package['x11-misc/synergy'],
  }

  file { '/etc/systemd/user/synergys.service':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/synergy/synergys.service',
    notify => Exec['synergy-systemd-daemon-reload'],
  }

  file { '/etc/systemd/user/synergys.socket':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/synergy/synergys.socket',
    notify => Exec['synergy-systemd-daemon-reload'],
  }

  exec { 'synergy-systemd-daemon-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  exec { 'synergy-enable-systemd-user-service':
    command => '/usr/bin/systemctl --user --global enable synergys.socket',
    creates => '/etc/systemd/user/sockets.target.wants/synergys.socket',
    require => File['/etc/systemd/user/synergys.socket'],
  }
}
