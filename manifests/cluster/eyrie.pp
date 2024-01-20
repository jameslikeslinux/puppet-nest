class nest::cluster::eyrie {
  # Disable VPN in favor of secure VLAN
  file { '/etc/systemd/system/openvpn-client@nest.service':
    ensure => link,
    target => '/dev/null',
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
