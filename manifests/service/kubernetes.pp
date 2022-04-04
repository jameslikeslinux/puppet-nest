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
  file { '/etc/cni/net.d/10-flannel.conflist':
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
    content => "KUBELET_ARGS=\"--config=/var/lib/kubelet/config.yaml --kubeconfig=/etc/kubernetes/kubelet.conf\"\n",
    notify  => Service['kubelet'],
  }

  file { '/etc/systemd/system/kubelet.service':
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
    'app-containers/cri-tools',
    'sys-cluster/kubeadm',
  ]:
    ensure => installed,
  }

  firewalld_port { 'vxlan':
    port     => 8472,
    protocol => udp,
  }

  sysctl { 'net.ipv4.ip_forward':
    ensure => present,
    value  => '1',
  }

  if $control_plane {
    firewalld_service { 'kube-apiserver':
      ensure => present,
    }
  }

  # Trust flannel network (let k8s manage its security)
  Firewalld_zone <| title == 'trusted' |> {
    sources +> '10.244.0.0/16',
  }
}
