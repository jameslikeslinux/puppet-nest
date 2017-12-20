define nest::portage::package_use (
  $package = $name,
  $use,
) {
  package_use { $package:
    use => $use,
  }

  exec { "emerge-newuse-${name}":
    command     => "/usr/bin/emerge -N1 ${package}",
    timeout     => 0,
    refreshonly => true,
    subscribe   => Package_use[$package],
  }

  if defined(Package[$name]) {
    Package_use[$package] ->
    Package[$name] ->
    Exec["emerge-newuse-${name}"]
  }
}
