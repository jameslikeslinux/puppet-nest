# Restart Kubernetes deployment
#
# @param name Name of the deployment to restart
# @param namespace Namespace where to find the deployment
plan nest::kubernetes::restart_deployment (
  String  $name,
  String  $namespace = 'default',
  Boolean $wait      = false,
) {
  run_command("kubectl rollout restart deployment ${name} -n ${namespace}", 'localhost', 'Restart deployment')

  if $wait {
    run_plan('nest::kubernetes::wait', {
      kind      => deployment,
      name      => $name,
      namespace => $namespace,
    })
  }
}
