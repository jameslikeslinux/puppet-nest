class nest::profile::base::git {
  case $facts['osfamily'] {
    'Gentoo': {
      package { 'dev-vcs/git':
        ensure => installed,
      }
    }

    'windows': {
      package { 'git':
        ensure   => installed,
        provider => 'cygwin',
      }
    }
  }
}
