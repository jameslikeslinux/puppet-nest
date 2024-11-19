# Setup container networking
plan nest::kubernetes::setup (
  TargetSpec $control_plane,
) {
  # Configure CoreDNS to forward requests to Nest nameserver. CoreDNS won't
  # start without the Calico pod network so updating this config before Calico
  # deploys guarantees CoreDNS will launch with the right config the first time.
  run_plan('nest::kubernetes::replace', {
    manifest => 'nest/kubernetes/manifests/coredns-config.yaml',
  })

  run_plan('nest::kubernetes::deploy', {
    service   => 'calico',
    app       => 'tigera-operator',
    namespace => 'tigera-operator',
    repo_name => 'projectcalico',
    repo_url  => 'https://docs.tigera.io/calico/charts',
    version   => '3.29.0',
    wait      => true,
  })

  run_plan('nest::kubernetes::calicoctl_apply', {
    control_plane => $control_plane,
    manifest      => 'nest/kubernetes/manifests/calico-config.yaml',
  })
}
