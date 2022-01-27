class nest::base::hosts {
  create_resources(host, $::nest::hosts)

  resources { 'host':
    purge => true,
  }
}
