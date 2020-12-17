define nest::lib::systemd_reload {
  exec { "systemd-daemon-reload-${name}":
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    noop        => $::is_container,
  }
}
