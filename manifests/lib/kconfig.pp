define nest::lib::kconfig (
  Stdlib::Absolutepath $config,
  Nest::Kconfig        $value,
) {
  $line_ensure = $value ? {
    undef   => 'absent',
    default => 'present',
  }

  $line = $value ? {
    Numeric   => "${name}=${value}",
    'n'       => "# ${name} is not set",
    /^(y|m)$/ => "${name}=${value}",
    default   => "${name}=\"${value}\"",
  }

  file_line { "kconfig-${name}-${value}":
    ensure            => $line_ensure,
    path              => $config,
    line              => $line,
    match             => "(^| )${name}[= ]",
    match_for_absence => true,
  }
}
