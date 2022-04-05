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
  $kubeadm_token_cmd = 'kubeadm token create --print-join-command'

  $kubeadm_join_cmd = run_command($kubeadm_token_cmd, get_targets($control_plane)[0], 'Get kubeadm join command', {
    _run_as => 'root',
  }).first.value['stdout'].chomp

  run_command($kubeadm_join_cmd, $targets, 'Join node to Kubernetes cluster', {
    _run_as => 'root',
  })
}
