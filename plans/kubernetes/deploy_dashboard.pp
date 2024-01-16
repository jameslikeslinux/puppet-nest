# Install and configure Kubernetes Dashboard
plan nest::kubernetes::deploy_dashboard {
  # Run once without hooks due to slow deployment on Eyrie
  run_plan('nest::kubernetes::helm_deploy', {
    name      => 'kubernetes-dashboard',
    chart     => 'kubernetes-dashboard',
    namespace => 'kubernetes-dashboard',
    repo_name => 'kubernetes-dashboard',
    repo_url  => 'https://kubernetes.github.io/dashboard/',
    version   => '7.0.0-alpha1',
    hooks     => false,
  })

  log::info('Waiting 60 seconds for cert-manager initialization')
  ctrl::sleep(60)

  # Run again with post-install hooks working
  run_plan('nest::kubernetes::helm_deploy', {
    name      => 'kubernetes-dashboard',
    chart     => 'kubernetes-dashboard',
    namespace => 'kubernetes-dashboard',
    repo_name => 'kubernetes-dashboard',
    repo_url  => 'https://kubernetes.github.io/dashboard/',
    version   => '7.0.0-alpha1',
  })

  run_plan('nest::kubernetes::apply', {
    manifest => 'nest/kubernetes/manifests/dashboard-users.yaml',
  })

  $check_for_token_cmd = 'grep -q token: $KUBECONFIG'
  $has_token = run_command($check_for_token_cmd, 'localhost', 'Check if kubeconfig contains auth token', {
    _catch_errors => true,
  }).first.ok

  unless $has_token {
    $get_token_cmd = 'kubectl get secret james-token -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d'
    $token = run_command($get_token_cmd, 'localhost', 'Get admin auth token').first.value['stdout'].chomp

    $edit_kubeconfig_cmd = "echo '    token: ${token}' >> \$KUBECONFIG"
    run_command($edit_kubeconfig_cmd, 'localhost', 'Add token to the kubeconfig')
  }
}
