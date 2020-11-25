define nest::lib::kernel_config (
  $value,
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

  file_line { "kernel-config-${name}-${value}":
    ensure            => $line_ensure,
    path              => '/usr/src/linux/.config',
    line              => $line,
    match             => "(^| )${name}[= ]",
    match_for_absence => true,
    require           => Exec['make defconfig'],
    notify            => Exec['make kernel'],
  }
}
