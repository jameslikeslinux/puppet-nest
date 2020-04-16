define nest::lib::kernel_config (
  $value
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
    require => Exec['make defconfig'],
    notify  => Exec['make kernel'],
  }
}
