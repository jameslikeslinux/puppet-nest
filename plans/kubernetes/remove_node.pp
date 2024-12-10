# Remove and reset Kubernetes nodes
#
# @param targets Nodes to remove
#
# @see https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down
plan nest::kubernetes::remove_node (
  TargetSpec $targets,
  Boolean    $drain = true,
) {
  $nodes = get_targets($targets).reduce({}) |$memo, $node| {
    $get_node_cmd = "kubectl get node ${node.name}"
    $result = run_command($get_node_cmd, 'localhost', "Check if ${node.name} is a cluster member", {
      _catch_errors => true,
    })

    $memo + { $node => $result.ok }
  }

  if $drain {
    $nodes.each |$node, $member| {
      if $member {
        $kubectl_drain_cmd = "kubectl drain ${node.name} --delete-emptydir-data --force --ignore-daemonsets"
        run_command($kubectl_drain_cmd, 'localhost', 'Drain node')
      }
    }
  }

  run_command('kubeadm reset --force', $targets, 'Reset node', {
    _run_as => 'root',
  })

  $nodes.each |$node, $member| {
    if $member {
      $kubectl_delete_node_cmd = "kubectl delete node ${node.name}"
      run_command($kubectl_delete_node_cmd, 'localhost', 'Delete node from cluster')
    }
  }
}
