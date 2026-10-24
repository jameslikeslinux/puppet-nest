# Preview by default; explicit execution closes only an already accepted native
# ordinary A/B cycle. Never prepares, accepts, reboots or adopts cleanup extras.
plan nest::host::update_finalize (
  TargetSpec                                      $target,
  Pattern[/\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/]      $transaction,
  Pattern[/\Asha256:[0-9a-f]{64}\z/]                 $release,
  String[1]                                       $hostname,
  Stdlib::Absolutepath                             $output_dir,
  Boolean                                         $execute = false,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 or $nodes[0].name =~ Pattern[/\A[^.]*-console(?:\.|\z)/] {
    fail_plan('Finalization requires exactly one non-console host', 'nest/update-finalize-target')
  }
  $context = {
    'transaction' => $transaction,
    'release'     => $release,
    'hostname'    => $hostname,
    'output_dir'  => $output_dir,
  }
  run_task('nest::retain_update_finalize', 'localhost', $context + { 'action' => 'check' })
  $status = run_command(
    ['nest', 'reset', 'status', $transaction, '--format=json'].shellquote,
    $nodes[0], 'Observe exact accepted boot before finalization', { '_run_as' => 'root' },
  ).first.value['stdout']
  $admission = run_task('nest::retain_update_finalize', 'localhost', $context + {
    'action' => 'admit',
    'status' => $status,
  }).first.value
  unless $admission['readback_verified'] == true and $admission['transaction'] == $transaction and
    $admission['release'] == $release and $admission['hostname'] == $hostname and $admission['action'] == 'admit' {
    fail_plan('Accepted status was not retained; no finalization started', 'nest/update-finalize-retention')
  }
  $command = ['nest', 'reset', 'finalize', $transaction, '--cleanup=owned', '--format=json']
  if $execute {
    $arguments = $command
    $action = 'complete'
  } else {
    $arguments = $command + ['--plan']
    $action = 'preview'
  }
  # Native mutation rechecks under its own transaction lock. Any disconnect or
  # refusal stops here; no automatic retry, accept, reset or reboot fallback.
  $report = run_command($arguments.shellquote, $nodes[0], 'Run exact native A/B finalization', {
    '_run_as' => 'root',
  }).first.value['stdout']
  $receipt = run_task('nest::retain_update_finalize', 'localhost', $context + {
    'action' => $action,
    'status' => $status,
    'report' => $report,
  }).first.value
  unless $receipt['readback_verified'] == true and $receipt['transaction'] == $transaction and
    $receipt['release'] == $release and $receipt['hostname'] == $hostname and $receipt['action'] == $action and
    (!$execute or ($receipt['state'] == 'finalized' and $receipt['cli_finalized'] == true)) {
    fail_plan('Finalization outcome was not retained; observe before any retry', 'nest/update-finalize-retention')
  }
  return($receipt + { 'admission' => $admission, 'execution_requested' => $execute })
}
