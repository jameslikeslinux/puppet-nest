# Read-only native eligibility for one existing transaction, never a reboot.
# The returned observation is not a lease, scope approval or boot acceptance.
plan nest::host::check_update_reboot (
  TargetSpec                                      $target,
  Pattern[/\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/]      $transaction,
  Pattern[/\Asha256:[0-9a-f]{64}\z/]                 $release,
  String[1]                                       $hostname,
  Stdlib::Absolutepath                             $output_dir,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 or $nodes[0].name =~ Pattern[/\A[^.]*-console(?:\.|\z)/] {
    fail_plan('Reboot planning requires exactly one non-console host', 'nest/update-reboot-plan-target')
  }
  $context = {
    'transaction' => $transaction,
    'release'     => $release,
    'hostname'    => $hostname,
    'output_dir'  => $output_dir,
  }
  run_task('nest::retain_update_reboot', 'localhost', $context + { 'action' => 'check' })
  $native = run_command(
    ['nest', 'reset', 'reboot', $transaction, '--plan', '--format=json'].shellquote,
    $nodes[0], 'Read native reboot eligibility without submission', { '_run_as' => 'root' },
  )
  $receipt = run_task('nest::retain_update_reboot', 'localhost', $context + {
    'action' => 'retain',
    'report' => $native.first.value['stdout'],
  }).first.value
  unless $receipt['readback_verified'] == true and $receipt['transaction'] == $transaction and
    $receipt['release'] == $release and $receipt['hostname'] == $hostname and $receipt['read_only'] == true and
    $receipt['execution_requested'] == false and $receipt['acceptance_recorded'] == false and
    $receipt['reboot_eligible'] =~ Boolean and
    (($receipt['reboot_eligible'] and $receipt['reboot_reason'] == 'eligible') or
      (!$receipt['reboot_eligible'] and $receipt['reboot_reason'] in ['already_requested', 'already_booted'])) {
    fail_plan('Native reboot eligibility was not retained with exact readback; no reboot submitted', 'nest/update-reboot-plan-retention')
  }
  return($receipt)
}
