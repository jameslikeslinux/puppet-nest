class nest::kubernetes {
  # lint:ignore:top_scope_facts
  $service        = pick_default($::kubernetes_service)
  $app            = pick_default($::kubernetes_app)
  $namespace      = pick_default($::kubernetes_namespace, 'default')
  $parent_service = pick_default($::kubernetes_parent_service)
  # lint:endignore

  if $service {
    $cron_job_offset  = stdlib::seeded_rand(60, $service)
    $fqdn             = "${service}.eyrie"
    $load_balancer_ip = lookup('nest::host_records')[$fqdn]
  } else {
    $cron_job_offset  = 0
    $fqdn             = undef
    $load_balancer_ip = undef
  }

  $db_password = $app ? {
    'mariadb'     => $parent_service ? {
      'bitwarden' => lookup('nest::service::bitwarden::database_password'),
      default     => undef,
    },
    'vaultwarden' => lookup('nest::service::bitwarden::database_password'),
    'wordpress'   => lookup('nest::service::wordpress::database_passwords')[$service],
    default       => undef,
  }

  $registry_auths = base64('encode', stdlib::to_json({
    'auths' => lookup('nest::registry_tokens').reduce({}) |$result, $token| {
      $result + { $token[0] => { 'auth' => base64('encode', $token[1]).chomp } }
    },
  }))

  if $app == 'vaultwarden' {
    $vaultwarden_db_url = base64('encode', "mysql://${service}:${db_password}@${service}-mariadb/${service}")

    # See: https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#secure-the-admin_token
    $vaultwarden_admin_token      = lookup('nest::service::bitwarden::admin_token')
    $vaultwarden_admin_token_hash = generate(
      '/bin/sh',
      '-c',
      "echo -n ${vaultwarden_admin_token.shellquote} | argon2 `openssl rand -base64 32` -e -id -k 65540 -t 3 -p 4",
    ).chomp
  }
}
