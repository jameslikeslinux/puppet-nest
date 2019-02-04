class nest::profile::base::git {
  $package_name = $facts['osfamily'] ? {
    'Gentoo' => 'dev-vcs/git',
    default  => git,
  }

  package { $package_name:
    ensure => installed,
  }
}
