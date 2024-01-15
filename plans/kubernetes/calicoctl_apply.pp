# Apply Calico network resources

# @param manifest Path or URL to the Calico manifest to deploy
plan nest::kubernetes::calicoctl_apply (
  String $manifest
) {
  if $manifest =~ Stdlib::HTTPUrl {
    $manifest_cmd = "curl ${manifest}"
  } else {
    $manifest_cmd = "cat ${find_file($manifest)}"
  }

  $apply_cmd = "${manifest_cmd} | kubectl exec -i -n kube-system calicoctl -- /calicoctl apply -f -"
  run_command($apply_cmd, 'localhost', "Apply Calico manifest ${manifest}")
}
