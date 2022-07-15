# Wait for a deployment or daemonset to rollout
#
# @param targets Host on which to run kubectl
# @param kind Type of rollout
# @param name Name of the object
# @param namespace Namespace where to find the object
# @param timeout How long to wait
plan nest::kubernetes::wait (
  TargetSpec $targets,
  Enum['daemonset', 'deployment'] $kind,
  String     $name,
  String     $namespace = 'default',
  String     $timeout   = '1h',
) {
  $wait_cmd = $kind ? {
    'daemonset'  => "kubectl rollout status daemonset ${name} -n ${namespace} --timeout=${timeout}",
    'deployment' => "kubectl wait --for=condition=Available deployment/${name} -n ${namespace} --timeout=${timeout}",
    default      => fail("Don't know how to wait for ${kind}"),
  }

  $result = run_command($wait_cmd, get_targets($targets)[0], "Wait for ${name} to rollout", {
    _env_vars     => { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' },
    _run_as       => 'root',
  })
}
