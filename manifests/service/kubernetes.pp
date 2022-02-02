class nest::service::kubernetes {
  # Install and enable container runtime
  package { 'app-emulation/cri-o':
    ensure => installed,
  }
  ->
  service { 'crio':
    enable => true,
  }

  # Install and enable kubelet with a service that works with CRI-O and kubeadm
  package { 'sys-cluster/kubelet':
    ensure => installed,
  }
  ->
  file { '/etc/kubernetes/kubelet.env':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "KUBELET_ARGS='--fail-swap-on=false'\n",
    notify  => Service['kubelet'],
  }


  file { '/etc/systemd/system/kubelet.service':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/kubernetes/kubelet.service'
  }
  ~>
  nest::lib::systemd_reload { 'kubernetes': }
  ->
  service { 'kubelet':
    enable => true,
  }

  # Install management tools
  package { [
    'app-emulation/cri-tools',
    'sys-cluster/kubeadm',
    'sys-cluster/kubectl',
  ]:
    ensure => installed,
  }

  firewall { '100 vxlan':
    source => "${facts['networking']['network']}/${facts['networking']['netmask']}",
    dport  => 8472,
    proto  => udp,
    action => accept,
  }

  sysctl { 'net.ipv4.ip_forward':
    ensure => present,
    value  => '1',
  }
}
