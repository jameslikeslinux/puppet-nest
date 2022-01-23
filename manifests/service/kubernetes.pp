class nest::service::kubernetes {
  package { [
    'app-emulation/cri-o',
    'app-emulation/cri-tools',
    'sys-cluster/kubeadm',
    'sys-cluster/kubectl',
    'sys-cluster/kubelet',
  ]:
    ensure => installed,
  }

  firewall { '100 vxlan':
    source => "${facts['networking']['network']}/${facts['networking']['netmask']}",
    dport  => 8472,
    proto  => udp,
    action => accept,
  }

  service { 'kubelet':
    enable  => true,
    require => Package['sys-cluster/kubelet'],
  }
}
