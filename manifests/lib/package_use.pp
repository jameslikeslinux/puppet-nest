define nest::lib::package_use (
  $use,
  $package = $name,
  $ensure  = 'present',
) {
  package_use { $package:
    ensure => $ensure,
    use    => $use,
  }

  exec { "emerge-newuse-${name}":
    command     => "/usr/bin/emerge -N1 ${package}",
    timeout     => 0,
    refreshonly => true,
    subscribe   => Package_use[$package],
  }

  if defined(Package[$name]) {
    Package_use[$package]
    -> Package[$name]
    -> Exec["emerge-newuse-${name}"]
  }
}
