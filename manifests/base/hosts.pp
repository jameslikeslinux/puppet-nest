class nest::base::hosts {
  create_resources(host, $::nest::hosts)

  host { 'localhost':
    ip => ['127.0.0.1', '::1'],
  }

  resources { 'host':
    purge => true,
  }
}
