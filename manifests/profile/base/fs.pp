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

    package { 'net-fs/samba':
      ensure => installed,
    }

    file { '/var/lib/samba/usershares':
      ensure  => directory,
      mode    => '1755',
      owner   => 'root',
      group   => 'root',
      require => Package['net-fs/samba'],
    }

    $samba_config = @(EOT)
      [global]
        usershare path = /var/lib/samba/usershares
        usershare max shares = 100
        usershare allow guests = yes
        usershare owner only = no

      [homes]
        comment = Home Directories
        browseable = no
        writable = yes
      | EOT

    file { '/etc/samba/smb.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $samba_config,
      require => File['/var/lib/samba/usershares'],
    }

    service { 'smbd':
      enable    => true,
      subscribe => File['/etc/samba/smb.conf'],
    }

    $fileserver_rules_ensure = $::nest::libvirt ? {
      true    => 'present',
      default => 'absent',
    }

    firewall { '100 fileserver':
      ensure  => $fileserver_rules_ensure,
      proto   => tcp,
      dport   => [139, 445, 2049],
      iniface => 'virbr0',
      state   => 'NEW',
      action  => accept,
    }
  } elsif !$::nest::live {
    package { 'sys-fs/cachefilesd':
      ensure => installed,
    }

    # Work around https://bugs.gentoo.org/show_bug.cgi?id=593088
    $cachefilesd_fix_path = @(EOT)
      [Service]
      ExecStart=
      ExecStart=/sbin/cachefilesd -n -f /etc/cachefilesd.conf
      | EOT

    file { '/etc/systemd/system/cachefilesd.service.d':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    file { '/etc/systemd/system/cachefilesd.service.d/10-fix-path.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $cachefilesd_fix_path,
      notify  => Exec['cachefilesd-systemd-daemon-reload'],
      require => Package['sys-fs/cachefilesd'],
    }

    exec { 'cachefilesd-systemd-daemon-reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
    }

    service { 'cachefilesd':
      enable  => true,
      require => Exec['cachefilesd-systemd-daemon-reload'],
    }
  }
}
