class nest::base::zfs {
  tag 'boot'
  tag 'kernel'

  if $nest::update_state and !$nest::zfs {
    fail('Shared update state requires ZFS')
  }

  if $nest::zfs {
    if $nest::zfs == 'fork' {
      $zfs_env = {
        'EGIT_OVERRIDE_REPO_OPENZFS_ZFS'   => 'https://gitlab.joyfullee.me/nest/forks/zfs.git',
        'EGIT_OVERRIDE_BRANCH_OPENZFS_ZFS' => 'main',
      }
      $zfs_unstable = '**'
    } else {
      $zfs_env = undef
      $zfs_unstable = true
    }

    nest::lib::package { 'sys-fs/zfs':
      ensure   => latest,
      binpkg   => false,
      env      => $zfs_env,
      unstable => $zfs_unstable,
      require  => Class['nest::base::kernel'],
    }

    $zfs_mount_activate_be_override = @(EOF)
      [Service]
      ExecStartPre=/usr/bin/nest beadm activate
      | EOF

    $zfs_mount_load_key_override = @(EOF)
      [Service]
      ExecStart=
      ExecStart=/sbin/zfs mount -al
      | EOF

    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      '/etc/systemd/system/zfs-mount.service.d':
        ensure => directory,
      ;

      '/etc/systemd/system/zfs-mount.service.d/10-activate-be.conf':
        content => $zfs_mount_activate_be_override,
        require => Package['app-admin/nest-cli'],
        tag     => 'nest_cli_safety',
      ;

      '/etc/systemd/system/zfs-mount.service.d/10-load-key.conf':
        content => $zfs_mount_load_key_override,
      ;
    }
    ~> nest::lib::systemd_reload { 'zfs':
      tag => 'nest_cli_safety',
    }

    if $nest::update_state {
      file { '/usr/local/sbin/nest-update-state':
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/nest/nest-update-state',
        tag    => 'nest_update_state',
      }

      file { '/etc/systemd/system/nest-update-state.service':
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/nest/cli/nest-update-state.service',
        notify => Nest::Lib::Systemd_reload['nest-update-state'],
        tag    => 'nest_update_state',
      }

      nest::lib::systemd_reload { 'nest-update-state':
        tag => 'nest_update_state',
      }

      # Do not restart on helper changes or unmount on stop. Both BEs must
      # receive this unit through ordinary managed configuration before use.
      $update_state_service_ensure = ($facts['build'] or $facts['is_container']) ? {
        true    => undef,
        default => running,
      }

      service { 'nest-update-state':
        ensure  => $update_state_service_ensure,
        enable  => true,
        require => [
          File['/usr/local/sbin/nest-update-state'],
          File['/etc/systemd/system/nest-update-state.service'],
          Nest::Lib::Systemd_reload['nest-update-state'],
          Package['app-admin/nest-cli'],
        ],
        tag     => 'nest_update_state',
      }
    }

    # On systems without ZFS root, the zfs module doesn't get loaded by dracut
    file { '/etc/modules-load.d/zfs.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "zfs\n",
    }

    # See: https://github.com/zfsonlinux/zfs/blob/master/etc/systemd/system/50-zfs.preset.in
    service { [
      'zfs-import-cache.service',
      'zfs-mount.service',
      'zfs-share.service',
      'zfs-zed.service',
      'zfs.target',
    ]:
      enable  => true,
      require => Package['sys-fs/zfs'],
    }

    unless $facts['build'] {
      exec { 'zgenhostid':
        command => '/sbin/zgenhostid',
        creates => '/etc/hostid',
      }

      if $facts['hostid'] and $facts['hostid'] == $facts['rpool_hostid'] {
        exec { 'generate-zpool-cache':
          command => "/sbin/zpool set cachefile= ${trusted['certname']}",
          creates => '/etc/zfs/zpool.cache',
        }
      }
    }

    unless $facts['is_container'] {
      # Manage swap volume properties for experimenting with workarounds listed in
      # https://github.com/openzfs/zfs/issues/7734
      zfs { "${facts['rpool']}/swap":
        compression    => 'off',
        sync           => 'standard',
        primarycache   => 'metadata',
        secondarycache => 'none',
        logbias        => 'throughput',
      }
    }

    # Avoid copying incompatible xattrs from NFS4 to ZFS
    file_line { 'xattr.conf-skip-nfs4_acl':
      path  => '/etc/xattr.conf',
      line  => "system.nfs4_acl\t\t\tskip",
      match => '^system.nfs4_acl\s+',
    }
  }
}
