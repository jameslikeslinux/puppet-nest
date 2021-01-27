class nest::service::php {
  nest::lib::package_use { 'dev-lang/php':
    use => ['curl', 'exif', 'fpm', 'gd', 'mysql', 'mysqli', 'soap', 'zip'],
  }

  portage::makeconf { 'php_targets':
    content => 'php7-4',
  }

  package { 'dev-lang/php':
    ensure => installed,
  }

  file_line { 'php.ini-max_execution_time':
    path    => '/etc/php/fpm-php7.4/php.ini',
    line    => 'max_execution_time = 120',
    match   => '^;?max_execution_time\s*=',
    require => Package['dev-lang/php'],
    notify  => Service['php-fpm@7.4'],
  }

  service { 'php-fpm@7.2':
    ensure  => stopped,
    enable  => false,
    require => Package['dev-lang/php'],
  }

  service { 'php-fpm@7.4':
    ensure  => running,
    enable  => true,
    require => Service['php-fpm@7.2'],
  }

  package { [
    'dev-php/pecl-imagick',
    'dev-php/pecl-ssh2',
  ]:
    ensure  => installed,
    require => Package['dev-lang/php'],
  }
}
