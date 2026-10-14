# @summary One-round CA rollback archive or verified Kite SSL transfer for 1928
# Remove after the staged root matrix is accepted; never changes live Kite SSL.
plan nest::build::stage3_1928_safety (
  Enum['backup_ca', 'import_kite'] $action,
) {
  if $action == 'backup_ca' {
    $backup = @(BACKUP)
      set -eu
      umask 077
      dir=/etc/puppetlabs/puppet/rollback-stage3-1928
      mkdir -p "$dir"
      chmod 700 "$dir"
      if [ ! -f "$dir/ca-before.tar" ]; then
        tar -C /etc/puppetlabs/puppetserver/ca -cf "$dir/ca-before.tar.partial" .
        chmod 600 "$dir/ca-before.tar.partial"
        mv "$dir/ca-before.tar.partial" "$dir/ca-before.tar"
      fi
      tar -tf "$dir/ca-before.tar" >/dev/null
      stat -c '%a %U %G %s %n' "$dir/ca-before.tar"
      sha256sum "$dir/ca-before.tar"
      | BACKUP
    run_command(['kubectl', 'exec', '-n', 'default', 'deploy/puppet-puppetserver',
      '-c', 'puppet-puppetserver', '--', 'sh', '-c', $backup].shellquote,
      'localhost', 'Retain secure production CA rollback archive')
  } else {
    run_plan('nest::build::stage3_1928_identity', action => 'prepare_kite', hostname => 'kite')
    run_command('install -d -m 0700 /modules/nest/downloads', 'localhost', 'Protect temporary identity transfer directory')
    $download = download_file('/etc/puppetlabs/puppet/ssl', 'stage3_1928_kite', 'kite',
      'Securely download existing verified Kite identity', '_run_as' => 'root')
    upload_file($download.first['path'], '/nest/stage3-1928/identities/kite/etc/puppetlabs/puppet/ssl',
      'falcon', 'Import Kite identity without reissuance', '_run_as' => 'root')
    run_plan('nest::build::stage3_1928_identity', action => 'verify', hostname => 'kite')
  }
}
