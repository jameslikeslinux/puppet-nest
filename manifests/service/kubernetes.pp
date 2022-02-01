class nest::service::kubernetes {
  # Install and enable container runtime
  package { 'app-emulation/cri-o':
    ensure => installed,
  }
  ->
  service { 'crio':
    enable => true,
  }

  # Install and enable kubelet, fixing dependency on container runtime
  package { 'sys-cluster/kubelet':
    ensure => installed,
  }
  ->
  exec { 'kubelet-requires-crio-not-docker':
    command => '/bin/sed -i "s/docker.service/crio.service/g" /lib/systemd/system/kubelet.service',
    onlyif  => '/bin/grep docker.service /lib/systemd/system/kubelet.service',
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
