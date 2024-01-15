# Remove and reset Kubernetes worker nodes
#
# @param targets Worker nodes to remove
#
# @see https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down
plan nest::kubernetes::remove_worker (
  TargetSpec $targets,
  Boolean    $drain = true,
) {
  $workers = get_targets($targets).reduce({}) |$memo, $worker| {
    $get_node_cmd = "kubectl get node ${worker.name}"
    $result = run_command($get_node_cmd, 'localhost', "Check if ${worker.name} is a cluster member", {
      _catch_errors => true,
    })

    $memo + { $worker => $result.first.ok }
  }

  if $drain {
    $workers.each |$worker, $member| {
      if $member {
        $kubectl_drain_cmd = "kubectl drain ${worker.name} --delete-emptydir-data --force --ignore-daemonsets"
        run_command($kubectl_drain_cmd, 'localhost', 'Drain worker node')
      }
    }
  }

  run_command('kubeadm reset --force', $targets, 'Reset node', {
    _run_as => 'root',
  })

  $workers.each |$worker, $member| {
    if $member {
      $kubectl_delete_node_cmd = "kubectl delete node ${worker.name}"
      run_command($kubectl_delete_node_cmd, 'localhost', 'Delete node from cluster')
    }
  }
}
