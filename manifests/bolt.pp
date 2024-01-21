class nest::bolt {
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

  if $helm_release {
    $wordpress_db_password = lookup('nest::service::wordpress::database_passwords')[$helm_release]
  } else {
    $wordpress_db_password = undef
  }
}
