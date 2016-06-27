class nest::apache {
  class { '::apache':
    mpm_module => 'worker',
  }

  ::apache::mod { 'log_config': }
  ::apache::mod { 'unixd': }

  nest::portage::package_use { 'httpd':
    package => 'www-servers/apache',
    use     => [
      'apache2_modules_access_compat',
      'apache2_modules_proxy',
      'apache2_modules_proxy_http',
      'threads'
    ],
  }

  # This is not at all necessary, but the default defines are not used
  # by puppetlabs/apache and it could lead to confusion.
  file_line { 'apache2-opts':
    path    => '/etc/conf.d/apache2',
    line    => 'APACHE2_OPTS=',
    match   => '^#?APACHE2_OPTS=',
    require => Class['::apache'],
    notify  => Class['::apache::service'],
  }
}
