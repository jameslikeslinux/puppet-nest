class nest::bolt {
  $helm_release = defined('$::helm_release') ? {
    true    => $::helm_release,
    default => undef,
  }

  $helm_chart = defined('$::helm_chart') ? {
    true    => $::helm_chart,
    default => undef,
  }

  $eyrie_host_key = base64('encode', lookup('nest::ssh_private_keys')['eyrie'])
}
