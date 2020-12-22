define nest::lib::systemd_reload {
  unless $facts['is_container'] {
    exec { "systemd-daemon-reload-${name}":
      command     => '/bin/systemctl daemon-reload',
      refreshonly => true,
    }
  }
}
