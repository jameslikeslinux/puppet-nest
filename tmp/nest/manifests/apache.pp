class nest::apache {
  class { '::apache':
    mpm_module => 'worker',
  }

  ::apache::mod { 'log_config': }
  ::apache::mod { 'unixd': }

  nest::portage::package_use { 'www-servers/apache':
    use => ['apache2_modules_access_compat', 'threads'],
  }

  file_line { 'apache2-opts':
    path    => '/etc/conf.d/apache2',
    line    => 'APACHE2_OPTS=',
    match   => '^#?APACHE2_OPTS=',
    require => Class['::apache'],
    notify  => Class['::apache::service'],
  }
}
