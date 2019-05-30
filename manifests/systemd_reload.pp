define nest::systemd_reload {
  $exec_noop = $facts['virtual'] == 'lxc'

  exec { "systemd-daemon-reload-${name}":
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    noop        => $exec_noop,
  }
}
