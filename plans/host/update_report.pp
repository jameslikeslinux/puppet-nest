# Read a retained native transaction without replaying any update phase.
# output_dir is on the Bolt supervisor, not the remote target. With the Nest
# container wrapper use a precreated directory under /modules/nest, then read
# the corresponding project path on the caller before handing it to Kanban.
plan nest::host::update_report (
  TargetSpec                                      $target,
  Pattern[/\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/]      $transaction,
  Pattern[/\Asha256:[0-9a-f]{64}\z/]                 $release,
  String[1]                                       $hostname,
  Stdlib::Absolutepath                             $output_dir,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 {
    fail_plan('Report collection requires exactly one host', 'nest/update-report-target')
  }
  # A remote export cannot repair a missing supervisor destination. Validate
  # the exact context and existing directory before contacting the host; this
  # read-only check is not a lease against later publication failure.
  run_task('nest::retain_update_report', 'localhost', {
    'action'      => 'check',
    'transaction' => $transaction,
    'release'     => $release,
    'hostname'    => $hostname,
    'output_dir'  => $output_dir,
  })
  $result = run_command(
    ['nest', 'reset', 'report', $transaction, '--format=json'].shellquote,
    $nodes[0],
    'Export sanitized stored update report without replay',
    { '_run_as' => 'root' },
  )
  $retained = run_task('nest::retain_update_report', 'localhost', {
    'report'      => $result.first.value['stdout'],
    'transaction' => $transaction,
    'release'     => $release,
    'hostname'    => $hostname,
    'output_dir'  => $output_dir,
  })
  $receipt = $retained.first.value
  unless $receipt['readback_verified'] == true and $receipt['id'] == $transaction and
    $receipt['release'] == $release and $receipt['hostname'] == $hostname {
    fail_plan('Stored transaction export was not retained with exact readback; do not replay update phases', 'nest/update-report-retention')
  }
  return $receipt
}
