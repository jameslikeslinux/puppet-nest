# Observe an existing release-owned hold and retain it before reset admission.
# Never creates/releases a hold, captures, prunes or restores a generation.
plan nest::host::check_update_backup (
  Hash $check,
  Hash $retention,
) {
  unless 'hold_id' in $check.keys {
    fail_plan('Preparation requires an explicit release-owned backup hold', 'nest/update-backup-retention')
  }
  # Validate the complete requirement and supervisor destination before contact.
  run_task('nest::retain_update_backup', 'localhost', {
    'action'    => 'check',
    'check'     => $check,
    'retention' => $retention,
  })
  $result = run_plan('nest::app::hermes::retain_generation', $check.filter |$key, $value| { $key != 'kind' } + {
    'action'  => 'check-hold',
    'release' => $retention['release'],
  })
  $receipt = run_task('nest::retain_update_backup', 'localhost', {
    'action'    => 'retain',
    'check'     => $check,
    'retention' => $retention,
    'report'    => $result.results[0].value['stdout'],
  }).results[0].value
  unless $receipt['verification_retained'] == true and $receipt['hold_checked'] == true and $receipt['readback_verified'] == true {
    fail_plan('Exact backup hold observation was not retained', 'nest/update-backup-retention')
  }
  return($receipt)
}
