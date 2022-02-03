# Reset Kubernetes worker nodes
#
# @param targets A list of worker nodes to reset
# @param control_plane The node that controls the workers
#
# @see https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down
plan nest::kubernetes::reset_worker (
  TargetSpec $targets,
  TargetSpec $control_plane,
) {
  $workers = get_targets($targets).reduce({}) |$memo, $worker| {
    $get_node_cmd = "kubectl get node ${worker.name}"
    $result = run_command($get_node_cmd, get_targets($control_plane)[0], "Check if ${worker.name} is a cluster member", {
      _catch_errors => true,
      _env_vars     => { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' },
      _run_as       => 'root',
    })

    $memo + { $worker => $result.first.ok }
  }

  $workers.each |$worker, $member| {
    if $member {
      $kubectl_drain_cmd = "kubectl drain ${worker.name} --delete-emptydir-data --force --ignore-daemonsets"
      run_command($kubectl_drain_cmd, get_targets($control_plane)[0], 'Drain worker node', {
        _env_vars => { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' },
        _run_as   => 'root',
      })
    }
  }

  # run_command('kubeadm reset --force', $targets, 'Reset node', {
  #   _run_as => 'root',
  # })

  $workers.each |$worker, $member| {
    if $member {
      $kubectl_delete_node_cmd = "kubectl delete node ${worker.name}"
      run_command($kubectl_delete_node_cmd, get_targets($control_plane)[0], 'Delete node from cluster', {
        _env_vars => { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' },
        _run_as   => 'root',
      })
    }
  }
}
