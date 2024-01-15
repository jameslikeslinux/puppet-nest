# Apply Kubernetes manifest

# @param manifest Path or URL to the Kubernets manifest to deploy
plan nest::kubernetes::apply (
  String $manifest
) {
  if $manifest =~ Stdlib::HTTPUrl {
    $manifest_real = $manifest
  } else {
    $manifest_real = find_file($manifest)
  }

  run_command("kubectl apply -f ${manifest_real}", 'localhost', "Apply Kubernetes manifest ${manifest}")
}
