# join nodes to Kubernetes cluster
#
# @param targets A list of nodes to join
# @param control_plane The node that controls the workers
#
# @see https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#join-nodes
plan nest::kubernetes::join_node (
  TargetSpec $targets,
  TargetSpec $control_plane,
) {
  $kubeadm_token = run_command('kubeadm token create', get_targets($control_plane)[0], 'Get kubeadm token', {
    _run_as => 'root',
  }).first.value['stdout'].chomp

  $ca_cert_hash_cmd = @(HASH_CMD)
    openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |
    openssl rsa -pubin -outform der 2>/dev/null |
    openssl dgst -sha256 -hex |
    sed 's/^.* //'
    | HASH_CMD
  $ca_cert_hash = run_command($ca_cert_hash_cmd, get_targets($control_plane)[0], 'Get discovery token CA cert hash', {
    _run_as => 'root',
  }).first.value['stdout'].chomp

  $kubeadm_join_cmd = "kubeadm join ${control_plane}:6443 --token ${kubeadm_token} --discovery-token-ca-cert-hash sha256:${ca_cert_hash}"
  run_command($kubeadm_join_cmd, $targets, 'Join node to Kubernetes cluster', {
    _run_as => 'root',
  })
}
