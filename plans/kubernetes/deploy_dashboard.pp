# Install and configure Kubernetes Dashboard
#
# @param version Helm chart version to install
plan nest::kubernetes::deploy_dashboard (
  String $version = '7.0.0-alpha1',
) {
  # Post-install hooks fail on slow cluster so try several times
  ctrl::do_until(limit => 3) || {
    run_plan('nest::kubernetes::helm_deploy', {
      release       => 'kubernetes-dashboard',
      chart         => 'kubernetes-dashboard',
      namespace     => 'kubernetes-dashboard',
      repo_name     => 'kubernetes-dashboard',
      repo_url      => 'https://kubernetes.github.io/dashboard/',
      version       => $version,
      _catch_errors => true,
    }) !~ Error
  }

  run_plan('nest::kubernetes::apply', {
    manifest => 'nest/kubernetes/manifests/dashboard-users.yaml',
  })

  $check_for_token_cmd = 'grep -q token: $KUBECONFIG'
  $has_token = run_command($check_for_token_cmd, 'localhost', 'Check if kubeconfig contains auth token', {
    _catch_errors => true,
  }).ok

  unless $has_token {
    $get_token_cmd = 'kubectl get secret james-token -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d'
    $token = run_command($get_token_cmd, 'localhost', 'Get admin auth token').first.value['stdout']

    $edit_kubeconfig_cmd = "echo '    token: ${token}' >> \$KUBECONFIG"
    run_command($edit_kubeconfig_cmd, 'localhost', 'Add token to the kubeconfig')
  }
}
