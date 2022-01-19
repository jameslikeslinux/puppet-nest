class nest::tool::bolt {
  package { 'bolt':
    install_options => ['--bindir', '/usr/local/bin'],
    provider        => gem,
    require         => File['/usr/local/bin/bolt'],  # overwrites wrapper
  }
}
