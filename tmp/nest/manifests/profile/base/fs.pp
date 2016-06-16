class nest::profile::base::fs {
  package { 'net-fs/nfs-utils':
    ensure => installed,
  }

  file { '/etc/systemd/system/nfs-server.service.d':
    ensure => directory,
    mode   => '0655',
    owner  => 'root',
    group  => 'root',

    # Not strictly required, but packages pull in systemd
    require => Package['net-fs/nfs-utils'],
  }

  $nfs_server_make_v4recovery = @(EOT)
    [Service]
    ExecStartPre=-/bin/mkdir -p /var/lib/nfs/v4recovery
    | EOT

  file { '/etc/systemd/system/nfs-server.service.d/10-v4recovery.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $nfs_server_make_v4recovery,
    notify  => Exec['nfs-server-systemd-daemon-reload'],
  }

  exec { 'nfs-server-systemd-daemon-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  if $::nest::fileserver {
    service { 'nfs-server':
      enable    => true,
      subscribe => Exec['nfs-server-systemd-daemon-reload'],
    }

    service { 'zfs-share':
      enable  => true,
      require => Package['sys-fs/zfs'],
    }
  } elsif !$::nest::live {
    package { 'sys-fs/cachefilesd':
      ensure => installed,
    }

    service { 'cachefilesd':
      enable  => true,
      require => Package['sys-fs/cachefilesd'],
    }
  }
}
