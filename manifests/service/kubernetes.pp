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
  ->
  service { [
    'crio',
    'kubelet',
  ]:
    enable => true,
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
