class nest::kubernetes {
  $helm_release = defined('$::helm_release') ? {
    true    => $::helm_release, # lint:ignore:top_scope_facts
    default => undef,
  }

  $helm_chart = defined('$::helm_chart') ? {
    true    => $::helm_chart, # lint:ignore:top_scope_facts
    default => undef,
  }

  $helm_namespace = defined('$::helm_namespace') ? {
    true    => $::helm_namespace, # lint:ignore:top_scope_facts
    default => 'default',
  }

  $helm_parent = defined('$::helm_parent') ? {
    true    => $::helm_parent, # lint:ignore:top_scope_facts
    default => 'default',
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

  if $helm_release {
    $fqdn = "${helm_release}.eyrie"
    $load_balancer_ip = lookup('nest::host_records')[$fqdn]
  } else {
    $fqdn = undef
    $load_balancer_ip = undef
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
    $vaultwarden_admin_token_hash = $vaultwarden_admin_token
    # $vaultwarden_admin_token_hash = generate(
    #   '/bin/zsh',
    #   '-c',
    #   "/usr/bin/argon2 $(/usr/sbin/openssl rand -base64 32) -e -id -k 65540 -t 3 -p 4 <<< ${vaultwarden_admin_token.shellquote}",
    # )
  }
}
