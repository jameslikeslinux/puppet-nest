# Explicit release-long retention; never captures, prunes or restores a backup.
plan nest::app::hermes::retain_generation (
  TargetSpec                                      $target,
  Enum['hold', 'check-hold', 'release-hold']       $action,
  Pattern[/\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/]      $hold_id,
  Pattern[/\Asha256:[0-9a-f]{64}\z/]                 $release,
  Pattern[/\A[A-Za-z0-9][A-Za-z0-9_.-]{0,127}\z/]    $checkpoint,
  Pattern[/\A[0-9a-f]{64}\z/]                       $expected_sha256,
  Optional[Integer[1, 604800]]                     $max_age_seconds   = undef,
  Stdlib::Absolutepath                             $backup_dir        = '/nest/backup/hermes',
  Pattern[/\A[a-z_][a-z0-9_-]{0,31}\z/]            $user              = 'joy',
  Array[String[1], 1, 128]                         $required_profiles = ['talon', 'star', 'beryl', 'quill'],
) {
  if ($action == 'release-hold') == ($max_age_seconds != undef) {
    fail_plan('hold and check-hold require max_age_seconds; release-hold refuses it', 'nest/hermes-generation-retention')
  }
  $nodes = get_targets($target)
  if $nodes.length != 1 or $required_profiles.unique != $required_profiles {
    fail_plan('Generation retention requires exactly one backup host and unique profiles', 'nest/hermes-generation-retention')
  }
  $node = $nodes[0]
  $helper = run_command('mktemp /tmp/nest-hermes-backup-generation.XXXXXXXX', $node,
    'Create unique Hermes retention helper path', { '_run_as' => 'root' }).first.value['stdout'].chomp
  upload_file('nest/hermes-backup-generation', $helper, $node, { '_run_as' => 'root' })
  $profiles = $required_profiles.map |$name| { ['--required-profile', $name] }.flatten
  $age = $max_age_seconds == undef ? {
    true    => [],
    default => ['--max-age-seconds', String($max_age_seconds)],
  }
  $arguments = [
    $helper, $action, '--backup-dir', $backup_dir, '--checkpoint', $checkpoint,
    '--expected-sha256', $expected_sha256,
    '--hold-id', $hold_id, '--release', $release,
  ] + $age + $profiles
  $command = @("COMMAND"/L)
    set -euo pipefail
    trap 'rm -f ${helper}' EXIT HUP INT TERM
    chown ${user.shellquote}:${user.shellquote} ${helper.shellquote}
    chmod 0700 ${helper.shellquote}
    cd /
    runuser -u ${user.shellquote} -- podman unshare ${arguments.shellquote}
    | COMMAND
  # No directory initialization, permission repair, retries or capture fallback.
  return run_command($command, $node, 'Apply exact explicit backup retention action', { '_run_as' => 'root' })
}
