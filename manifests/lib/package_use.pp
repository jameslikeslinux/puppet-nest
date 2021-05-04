define nest::lib::package_use (
  Optional[Nest::UseFlags]  $use,
  Enum['present', 'absent'] $ensure  = 'present',
  String                    $package = $name,
) {
  package_use { $name:
    ensure => $ensure,
    name   => $package,
    use    => $use,
  }

  if defined(Package[$name]) {
    exec { "emerge-newuse-${name}":
      command     => "/usr/bin/emerge -N ${package}",
      timeout     => 0,
      refreshonly => true,
    }

    Package_use[$name]
    ~> Exec["emerge-newuse-${name}"]
    ~> Package[$name]
  }
}
