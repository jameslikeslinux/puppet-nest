class nest::profile::base::packages {
  if $::nest::package_server == true {
    include '::nest::apache'

    file { '/var/www/localhost/htdocs/packages':
      ensure  => symlink,
      target  => '/usr/portage/packages',
      require => Class['::nest::apache'],
    }
  }
}
