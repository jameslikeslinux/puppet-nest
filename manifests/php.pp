class nest::php {
  nest::portage::package_use { 'app-eselect/eselect-php':
    use => 'fpm',
  }

  nest::portage::package_use { 'dev-lang/php':
    use => ['curl', 'fpm', 'gd', 'mysql', 'mysqli', 'soap'],
  }

  portage::makeconf { 'php_targets':
    ensure  => absent,
    content => 'php7-0',
  }

  package { 'dev-lang/php':
    ensure  => installed,

    # The dependency on Nest::Portage::Package_use['dev-lang/php'] is implied;
    # eselect-php needs to use fpm too
    require => Nest::Portage::Package_use['app-eselect/eselect-php'],
  }

  service { 'php-fpm@7.2':
    ensure  => stopped,
    enable  => false,
    require => Package['dev-lang/php'],
  }

  service { 'php-fpm@7.1':
    ensure  => running,
    enable  => true,
    require => Service['php-fpm@7.2'],
  }

  package { 'dev-php/pecl-ssh2':
    ensure => installed,
  }

  apache::fastcgi::server { 'php':
    host       => '127.0.0.1:9000',
    timeout    => 600,
    flush      => false,
    faux_path  => '/var/www/php.fcgi',
    fcgi_alias => '/php.fcgi',
    file_type  => 'application/x-httpd-php'
  }
}
