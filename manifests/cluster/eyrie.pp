class nest::cluster::eyrie {
  # Disable VPN in favor of secure VLAN
  Service <| title == 'openvpn-client@nest' |> {
    enable => false,
  }

  file { '/etc/systemd/system/openvpn-client@nest.service':
    ensure => link,
    target => '/dev/null',
  }

  # Conflicts with routing between networks
  Firewalld_zone <| title == 'internal' |> {
    sources => undef,
  }

  # Allow routing between kubernetes and Nest
  Firewalld_zone <| title == 'kubernetes' |> {
    sources +> '172.22.0.0/24',
  }

  firewalld_rich_rule { 'nest':
    ensure => present,
    zone   => 'kubernetes',
    source => '172.22.0.0/24',
    action => accept,
  }

  firewalld_rich_rule { 'falcon':
    ensure => present,
    zone   => 'kubernetes',
    source => '172.22.4.2',
    action => accept,
  }

  # Control plane
  if $trusted['certname'] == 'eagle' {
    service { 'nfs-server':
      enable => true,
    }

    service { 'zfs-share':
      enable  => true,
      require => Package['sys-fs/zfs'],
    }

    firewalld_service { 'nfs':
      ensure => present,
      zone   => 'kubernetes',
    }

    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      '/etc/systemd/system/kubelet.service.d':
        ensure => directory,
      ;

      '/etc/systemd/system/kubelet.service.d/10-require-etcd-mount.conf':
        content => "[Service]\nExecCondition=/usr/sbin/mountpoint -q /var/lib/etcd\n",
      ;
    }
  }
}
