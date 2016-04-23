define nest::portage::package_use (
  $use,
) {
  package_use { $name:
    use => $use,
  }

  exec { "emerge-newuse-${name}":
    command     => "/usr/bin/emerge -N1 ${name}",
    timeout     => 0,
    refreshonly => true,
    subscribe   => Package_use[$name],
  }

  if defined(Package[$name]) {
    Package_use[$name] ->
    Package[$name] ->
    Exec["emerge-newuse-${name}"]
  }
}
