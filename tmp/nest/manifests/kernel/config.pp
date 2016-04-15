define nest::kernel::config (
  $value,
) {
  if is_numeric($value) {
    $line = "${name}=${value}"
  } else {
    $line = $value ? {
      'n'       => "# ${name} is not set",
      /^(y|m)$/ => "${name}=${value}",
      default   => "${name}=\"${value}\"",
    }
  }

  file_line { "kernel-config-${name}-${value}":
    path    => '/usr/src/linux/.config',
    line    => $line,
    match   => "(^| )${name}[= ]",
  }
}
