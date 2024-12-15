# Replace Kubernetes manifest
#
# @param manifest Path or URL to the Kubernetes manifest to deploy
plan nest::kubernetes::replace (
  String $manifest
) {
  if $manifest =~ Stdlib::HTTPUrl {
    $manifest_real = $manifest
  } else {
    $manifest_real = find_file($manifest)
  }

  run_command("kubectl replace -f ${manifest_real}", 'localhost', "Replace Kubernetes manifest ${manifest}")
}
