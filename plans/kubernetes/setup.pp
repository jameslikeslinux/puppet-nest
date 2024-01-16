# Setup container networking
plan nest::kubernetes::setup {
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
