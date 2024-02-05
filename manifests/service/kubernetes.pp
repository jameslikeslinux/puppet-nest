class nest::service::kubernetes (
  Boolean $control_plane = false,
) {
  include 'nest'

  File {
    mode  => '0644',
    owner => 'root',
    group => 'root',
  }

  # Install and enable container runtime
  package { 'app-containers/cri-o':
    ensure => installed,
  }
  ->
  file { '/etc/crio/crio.conf.d/10-crun.conf':
    source => 'puppet:///modules/nest/kubernetes/crio-crun.conf',
  }
  ~>
  service { 'crio':
    enable => true,
  }

  # Install and enable kubelet with a service that works with CRI-O and kubeadm
  package { 'sys-cluster/kubelet':
    ensure => installed,
  }
  ->
  file { '/etc/kubernetes/kubelet.env':
    content => epp('nest/kubernetes/kubelet.env.epp'),
    notify  => Service['kubelet'],
  }

  file { '/etc/systemd/system/kubelet.service':
    source => 'puppet:///modules/nest/kubernetes/kubelet.service',
  }
  ~>
  nest::lib::systemd_reload { 'kubernetes': }
  ->
  service { 'kubelet':
    enable => true,
  }

  # Install management tools
  package { [
    'app-containers/cri-tools',
    'sys-cluster/ipvsadm',
    'sys-cluster/kubeadm',
  ]:
    ensure => installed,
  }

  sysctl { 'net.ipv4.ip_forward':
    ensure => present,
    value  => '1',
  }

  # Allow forwarding and control access between networks used by Kubernetes
  firewalld_zone { 'kubernetes':
    ensure     => present,
    interfaces => $nest::external_interfaces,
    masquerade => true,
    sources    => [
      '10.96.0.0/12',   # K8s service network
      '192.168.0.0/16', # Calico pod network
      '172.22.0.0/24',  # Nest VPN
      "${facts['networking']['network']}/${facts['networking']['netmask']}", # Host pod network
    ],
    target     => 'default',
  }
  ->
  exec { 'firewalld-kubernetes-add-forward':
    command => nest::firewall_cmd('--zone=kubernetes --add-forward'),
    unless  => nest::firewall_cmd('--zone=kubernetes --query-forward'),
    notify  => Class['firewalld::reload'],
  }

  Firewalld_port {
    zone => 'kubernetes',
  }

  Firewalld_service {
    zone => 'kubernetes',
  }

  Firewalld_rich_rule {
    zone => 'kubernetes',
  }

  if $control_plane {
    firewalld_service { 'kube-control-plane':
      ensure => present,
    }

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
  } else {
    firewalld_service { 'kubelet-worker':
      ensure => present,
    }
  }

  firewalld_service { 'kubelet':
    ensure => present,
  }

  # Allow BGP for kube-vip
  firewalld_service { 'bgp':
    ensure => present,
  }

  # Allow cluster access to Calico
  firewalld_custom_service { 'calico':
    ensure => present,
    ports  => [
      { 'port' => 1790, 'protocol' => 'tcp' }, # BGP
      { 'port' => 5473, 'protocol' => 'tcp' }, # Typha
    ]
  }
  ->
  firewalld_service { 'calico':
    ensure => present,
  }

  firewalld_rich_rule {
    default:
      ensure => present,
      action => accept,
    ;

    # Allow pods to access cluster services
    'pods-to-cluster':
      source => '192.168.0.0/16',
      dest   => '10.96.0.0/12';
    'pods-to-lb':
      source => '192.168.0.0/16',
      dest   => '172.21.0.0/16',
    ;

    # Allow external access
    'nest':
      source => '172.22.0.0/24';
    'falcon':
      source => '172.22.4.2',
    ;
  }

  file { '/usr/local/bin/calicoctl':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => "https://github.com/projectcalico/calico/releases/download/v3.27.0/calicoctl-linux-${facts['profile']['architecture']}",
    replace => false,
  }
}
