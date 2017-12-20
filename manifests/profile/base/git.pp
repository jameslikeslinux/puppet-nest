class nest::profile::base::git {
  package { 'dev-vcs/git':
    ensure => installed,
  }
}
