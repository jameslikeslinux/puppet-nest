define nest::lib::package_use (
  Variant[String, Array[String]] $use,
  String                         $package = $name,
  Enum['present', 'absent']      $ensure  = 'present',
) {
  package_use { $package:
    ensure => $ensure,
    use    => $use,
  }

  if defined("Package[${name}]") {
    exec { "emerge-newuse-${name}":
      command     => "/usr/bin/emerge -N ${package}",
      timeout     => 0,
      refreshonly => true,
    }

    Package_use[$package]
    ~> Exec["emerge-newuse-${name}"]
    ~> Package[$name]
  }
}
