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
  return $retained.first.value
}
