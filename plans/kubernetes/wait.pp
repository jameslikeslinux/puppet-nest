# Wait for a deployment or daemonset to rollout
#
# @param kind Type of rollout
# @param name Name of the object
# @param namespace Namespace where to find the object
# @param timeout How long to wait
plan nest::kubernetes::wait (
  Enum['daemonset', 'deployment', 'pod'] $kind,
  String     $name,
  String     $namespace = 'default',
  String     $timeout   = '1h',
) {
  $wait_cmd = $kind ? {
    'daemonset'  => "kubectl rollout status daemonset ${name} -n ${namespace} --timeout=${timeout}",
    'deployment' => "kubectl wait --for=condition=Available deployment/${name} -n ${namespace} --timeout=${timeout}",
    'pod'        => "kubectl wait --for=condition=Ready pod/${name} -n ${namespace} --timeout=${timeout}",
    default      => fail("Don't know how to wait for ${kind}"),
  }

  run_command($wait_cmd, 'localhost', "Wait for ${name} to rollout")
}
