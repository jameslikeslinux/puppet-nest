# Setup container networking
plan nest::kubernetes::setup {
  # Configure CoreDNS to forward requests to Nest nameserver. CoreDNS won't
  # start without the Calico pod network so updating this config before Calico
  # deploys guarantees CoreDNS will launch with the right config the first time.
  $replace_coredns_config_cmd = 'kubectl replace -f https://gitlab.james.tl/nest/kubernetes/-/raw/main/coredns-config.yaml'
  run_command($replace_coredns_config_cmd, 'localhost', 'Replace CoreDNS config')

  run_plan('nest::kubernetes::helm_deploy', {
    name      => 'calico',
    chart     => 'tigera-operator',
    namespace => 'tigera-operator',
    repo_name => 'projectcalico',
    repo_url  => 'https://docs.tigera.io/calico/charts',
    version   => '3.27.0',
  })

  log::info('Waiting 30 seconds for calico-system initialization')
  ctrl::sleep(30)

  run_plan('nest::kubernetes::wait', {
    kind      => daemonset,
    name      => 'calico-node',
    namespace => 'calico-system',
  })

  log::info('Waiting 60 seconds for calico-apiserver initialization')
  ctrl::sleep(60)

  run_plan('nest::kubernetes::wait', {
    kind      => deployment,
    name      => 'calico-apiserver',
    namespace => 'calico-apiserver',
  })

  run_plan('nest::kubernetes::wait', {
    kind      => deployment,
    name      => 'coredns',
    namespace => 'kube-system',
  })
}
