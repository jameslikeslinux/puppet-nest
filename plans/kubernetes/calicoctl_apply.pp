# Apply Calico network resources

# @param manifest Path or URL to the Calico manifest to deploy
plan nest::kubernetes::calicoctl_apply (
  TargetSpec $control_plane,
  String $manifest,
) {
  $target = get_targets($control_plane)[0]

  if $manifest =~ Stdlib::HTTPUrl {
    $manifest_real = $manifest
  } else {
    $manifest_real = '/tmp/calico-config.yaml'
    upload_file($manifest, $manifest_real, $target)
  }

  $apply_cmd = "calicoctl apply -f ${manifest_real}"
  run_command($apply_cmd, get_targets($control_plane)[0], "Apply Calico manifest ${manifest}")
}
