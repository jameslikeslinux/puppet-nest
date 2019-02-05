class nest::node::puppet {
  firewall { '100 docker to puppetserver':
    iniface => 'docker_gwbridge',
    proto   => tcp,
    dport   => 8140,
    state   => 'NEW',
    action  => accept,
  }

  # Give host name to access the SSL-protected PuppetDB running in Docker
  host { 'puppetdb':
    ip => '127.0.80.81',
  }
}
