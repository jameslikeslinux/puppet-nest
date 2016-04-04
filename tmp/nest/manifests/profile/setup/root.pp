class nest::profile::setup::root {
  package { 'app-shells/zsh':
    ensure => installed,
  }

  user { 'root':
    shell   => '/bin/zsh',
    require => Package['app-shells/zsh'],
  }
}
