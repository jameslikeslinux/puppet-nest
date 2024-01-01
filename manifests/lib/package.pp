define nest::lib::package (
  Boolean                  $binpkg  = true,
  String                   $ensure  = 'installed',
  Hash                     $env     = {},
  String                   $package = $name,
  Optional[Nest::UseFlags] $use     = undef,
  Boolean                  $world   = true,
) {
  if !$binpkg {
    if defined(Package_env[$name]) {
      Package_env <| title == $name |> {
        env    +> 'no-buildpkg.conf',
        before +> Package[$name],
      }
    } else {
      package_env { $name:
        name   => $package,
        env    => 'no-buildpkg.conf',
        before => Package[$name],
      }
    }

    $install_options = [{ '--usepkg' => 'n' }]
  } else {
    $install_options = undef
  }

  unless $env.empty {
    $env_name = "${name.regsubst('^.*/', '')}.conf"
    $env_content = $env.map |$k, $v| {
      "${k}=\"${v}\"\n"
    }.join

    file { "/etc/portage/env/${env_name}":
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $env_content,
    }

    if defined(Package_env[$name]) {
      Package_env <| title == $name |> {
        env     +> $env_name,
        before  +> Package[$name],
        require +> File["/etc/portage/env/${env_name}"],
      }
    } else {
      package_env { $name:
        name    => $package,
        env     => $env_name,
        before  => Package[$name],
        require => File["/etc/portage/env/${env_name}"],
      }
    }
  }

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
    ensure          => $ensure,
    install_options => $install_options,
    name            => $package,
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
