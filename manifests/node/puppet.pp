class nest::node::puppet {
  firewall { '100 docker to puppetserver':
    iniface => 'docker_gwbridge',
    proto   => tcp,
    dport   => 8140,
    state   => 'NEW',
    action  => accept,
  }
}
