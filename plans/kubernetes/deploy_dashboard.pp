# Install and configure Kubernetes Dashboard
#
# @param version Helm chart version to install
plan nest::kubernetes::deploy_dashboard (
  String $version = '7.4.0',
) {
  run_plan('nest::kubernetes::deploy', {
    service   => 'kubernetes-dashboard',
    app       => 'kubernetes-dashboard',
    namespace => 'kubernetes-dashboard',
    repo_name => 'kubernetes-dashboard',
    repo_url  => 'https://kubernetes.github.io/dashboard/',
    version   => $version,
    wait      => true,
  })

  run_plan('nest::kubernetes::apply', {
    manifest => 'nest/kubernetes/manifests/dashboard-users.yaml',
  })

  # Wait for auth token
  ctrl::sleep(10)

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
