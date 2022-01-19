class nest::tool::bolt {
  if $facts['build'] == 'bolt' {
    package { 'bolt':
      install_options => ['--bindir', '/usr/local/bin'],
      provider        => gem,
    }
  } else {
    file { '/usr/local/bin/bolt':
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => epp('nest/scripts/bolt.sh.epp'),
    }
  }
}
