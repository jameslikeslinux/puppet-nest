# Manage per-user enablement in images without contacting a running manager.
define nest::lib::user_service (
  String[1]                  $unit,
  String[1]                  $user,
  Enum['stopped','running']  $ensure    = 'stopped',
  Boolean                    $enable    = false,
  String[1]                  $target    = 'default.target',
  Optional[String[1]]        $unit_file = undef,
) {
  if $facts['is_container'] {
    $user_dir = "/home/${user}/.config/systemd/user"
    $wants_dir = "${user_dir}/${target}.wants"
    $link_target = pick($unit_file, $unit)

    if $enable {
      ensure_resource('file', $wants_dir, {
        'ensure' => 'directory',
        'mode'   => '0755',
        'owner'  => $user,
        'group'  => $user,
      })

      file { "${wants_dir}/${unit}":
        ensure  => link,
        target  => "../${link_target}",
        owner   => $user,
        group   => $user,
        require => File[$wants_dir],
      }
    } else {
      ensure_resource('file', "${wants_dir}/${unit}", {
        'ensure' => 'absent',
      })
    }
  } else {
    systemd::user_service { $title:
      ensure => $ensure,
      enable => $enable,
      unit   => $unit,
      user   => $user,
    }

    # Upstream wraps queries in systemd-run. Expected nonzero probe results
    # then leave failed transient units in the user's manager on every run.
    # Query the same user bus directly; retain upstream service actions.
    $query = ['systemctl', '--user', '--machine', "${user}@.host"]
    if $ensure == 'running' {
      Exec <| title == "Start user service ${unit} for user ${user}" |> {
        unless => [$query + ['is-active', $unit]],
      }
    } else {
      Exec <| title == "Stop user service ${unit} for user ${user}" |> {
        onlyif => [$query + ['is-active', $unit]],
      }
    }

    if $enable {
      Exec <| title == "Enable user service ${unit} for user ${user}" |> {
        unless => [$query + ['is-enabled', $unit]],
      }
    } else {
      Exec <| title == "Disable user service ${unit} for user ${user}" |> {
        onlyif => [$query + ['is-enabled', $unit]],
      }
    }
  }
}
