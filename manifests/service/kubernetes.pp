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

  # Provide initial CNI config so CoreDNS doesn't deploy to Podman network.
  # CRI-O picks this up dynamically if it's running.
  file { '/etc/cni/net.d/10-calico.conflist':
    replace => false,
    source  => 'puppet:///modules/nest/kubernetes/cni-conf.json',
    require => Package['app-containers/cri-o'],
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
    ensure  => present,
    sources => [
      '10.96.0.0/12',   # K8s service network
      '192.168.0.0/16', # Calico pod network
      "${facts['networking']['network']}/${facts['networking']['netmask']}",  # Host pod network
    ],
    target  => 'default',
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
  } else {
    firewalld_service { 'kubelet-worker':
      ensure => present,
    }
  }

  firewalld_service { 'kubelet':
    ensure => present,
  }

  # Allow BGP for Calico
  firewalld_service { 'bgp':
    ensure => present,
  }

  # Allow pods to access cluster services
  firewalld_rich_rule { 'calico':
    ensure => present,
    source => '192.168.0.0/16',
    dest   => '10.96.0.0/12',
    action => accept,
  }

  # Allow cluster access to Calico Typha
  firewalld_port { 'typha':
    ensure   => present,
    port     => 5473,
    protocol => 'tcp',
  }
}
