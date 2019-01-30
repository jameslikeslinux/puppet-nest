class nest::profile::workstation::barrier {
  package { 'x11-misc/barrier':
    ensure => installed,
  }

  file { '/etc/barrier.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $::nest::barrier_config,
    require => Package['x11-misc/barrier'],
  }

  # Try to prevent segfaults every 10 seconds due to missing X server
  $barriers_safe_content = @(EOT)
    #!/bin/bash
    [ -n "$DISPLAY" ] && exec /usr/bin/barriers "$@"
    | EOT

  file { '/usr/bin/barriers.safe':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $barriers_safe_content,
  }

  file { '/etc/systemd/user/barriers.service':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/barrier/barriers.service',
    notify => Exec['barrier-systemd-daemon-reload'],
  }

  exec { 'barrier-systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  exec { 'barrier-enable-systemd-user-service':
    command => '/bin/systemctl --user --global enable barriers.service',
    creates => '/etc/systemd/user/default.target.wants/barriers.service',
    require => File['/etc/systemd/user/barriers.service'],
  }
}
