# Initialize Kubernetes control plane
#
# @param target Host to initialize as the control plane
# @param name Name of the cluster to configure
plan nest::kubernetes::init (
  TargetSpec $target,
  String     $name,
) {
  $targets = get_targets($target)
  if $targets.length != 1 {
    fail('This plan only supports initializing one control plane node')
  }
  $control_plane = $targets[0]

  run_command('systemctl start crio', $target, 'Start CRI-O', {
    _run_as => 'root',
  })

  run_command('systemctl stop kubelet', $target, 'Stop kubelet', {
    _run_as => 'root',
  })

  $kubeadm_config = epp('nest/kubernetes/kubeadm-config.yaml.epp', {
    clusterName          => $name,
    controlPlaneEndpoint => $control_plane.name,
  })
  write_file($kubeadm_config, '/root/kubeadm-config.yaml', $target, {
    _run_as => 'root',
  })

  $kubeadm_init_cmd = 'kubeadm init --config=/root/kubeadm-config.yaml --ignore-preflight-errors=Swap'
  run_command($kubeadm_init_cmd , $target, 'Run kubeadm init', {
    _run_as => 'root',
  })

  run_command('rm -f /root/kubeadm-config.yaml', $target, 'Remove kubeadm config file', {
    _run_as => 'root',
  })

  $kubeconfig_dest     = "/nest/home/kubeconfigs/${name}.conf"
  $copy_kubeconfig_cmd = "cp /etc/kubernetes/admin.conf ${kubeconfig_dest} && chown james ${kubeconfig_dest}"
  run_command($copy_kubeconfig_cmd, $target, 'Copy kubeconfig to Nest home', {
    _run_as => 'root',
  })

  # Configure CoreDNS to forward requests to Nest nameserver. CoreDNS won't
  # start without the Calico pod network so updating this config before Calico
  # deploys guarantees CoreDNS will launch with the right config the first time.
  $replace_coredns_config_cmd = 'kubectl replace -f https://gitlab.james.tl/nest/kubernetes/-/raw/main/coredns-config.yaml'
  run_command($replace_coredns_config_cmd, $target, 'Replace CoreDNS config', {
    _env_vars => { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' },
    _run_as   => 'root',
  })

  run_plan('nest::kubernetes::apply', $target, {
    manifest => 'https://gitlab.james.tl/nest/kubernetes/-/raw/main/calico.yaml',
  })

  run_plan('nest::kubernetes::wait', $target, {
    kind      => daemonset,
    name      => 'calico-node',
    namespace => 'kube-system',
  })

  run_plan('nest::kubernetes::wait', $target, {
    kind      => deployment,
    name      => 'coredns',
    namespace => 'kube-system',
  })
}
