define nest::lib::package (
  String                   $ensure  = 'present',
  String                   $package = $name,
  Optional[Nest::UseFlags] $use     = undef,
  Boolean                  $world   = true,
) {
  $use_ensure = $use ? {
    undef   => 'absent',
    default => 'present',
  }

  nest::lib::package_use { $name:
    ensure => $use_ensure,
    name   => $package,
    use    => $use,
  }

  package { $name:
    ensure => $ensure,
    name   => $package,
  }

  if $world {
    exec { "emerge-select-${name}":
      command => "/usr/bin/emerge --noreplace ${package.shellquote}",
      unless  => "/bin/grep -Fx ${package.shellquote} /var/lib/portage/world",
      require => Package[$name],
    }
  } else {
    exec { "emerge-deselect-${name}":
      command => "/usr/bin/emerge --deselect ${package.shellquote}",
      onlyif  => "/bin/grep -Fx ${package.shellquote} /var/lib/portage/world",
      require => Package[$name],
    }
  }
}
