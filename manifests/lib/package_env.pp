define nest::lib::package_env (
  String $package = $name,
  Hash   $env     = {},
) {
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

    if defined(Package[$name]) {
      Package_env[$name]
      -> Package[$name]
    }
  }
}
