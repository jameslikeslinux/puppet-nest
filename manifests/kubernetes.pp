class nest::kubernetes {
  # lint:ignore:top_scope_facts
  $helm_release   = pick_default($::helm_release)
  $helm_chart     = pick_default($::helm_chart)
  $helm_namespace = pick_default($::helm_namespace, 'default')
  $helm_parent    = pick_default($::helm_parent)
  # lint:endignore

  if $helm_release {
    $cron_job_offset  = stdlib::seeded_rand(60, $helm_release)
    $fqdn             = "${helm_release}.eyrie"
    $load_balancer_ip = lookup('nest::host_records')[$fqdn]
  } else {
    $cron_job_offset  = 0
    $fqdn             = undef
    $load_balancer_ip = undef
  }

  $db_password = $helm_chart ? {
    'mariadb'     => $helm_parent? {
      'bitwarden' => lookup('nest::service::bitwarden::database_password'),
      default     => undef,
    },
    'vaultwarden' => lookup('nest::service::bitwarden::database_password'),
    'wordpress'   => lookup('nest::service::wordpress::database_passwords')[$helm_release],
    default       => undef,
  }

  $registry_auths = base64('encode', stdlib::to_json({
    'auths' => lookup('nest::registry_tokens').reduce({}) |$result, $token| {
      $result + { $token[0] => { 'auth' => base64('encode', $token[1]).chomp } }
    },
  }))

  if $helm_chart == 'vaultwarden' {
    $vaultwarden_db_url = base64('encode', "mysql://${helm_release}:${db_password}@${helm_release}-mariadb/${helm_release}")

    # See: https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#secure-the-admin_token
    $vaultwarden_admin_token      = lookup('nest::service::bitwarden::admin_token')
    $vaultwarden_admin_token_hash = generate(
      '/bin/sh',
      '-c',
      "echo -n ${vaultwarden_admin_token.shellquote} | argon2 `openssl rand -base64 32` -e -id -k 65540 -t 3 -p 4",
    ).chomp
  }
}
