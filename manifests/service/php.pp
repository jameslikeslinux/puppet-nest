class nest::service::php {
  portage::makeconf { 'php_targets':
    content => 'php8-1',
    tag     => 'profile',
  }

  nest::lib::package { 'dev-lang/php':
    ensure => installed,
    use    => ['curl', 'exif', 'fpm', 'gd', 'mysql', 'mysqli', 'soap', 'zip'],
  }

  file_line { 'php.ini-max_execution_time':
    path    => '/etc/php/fpm-php8.1/php.ini',
    line    => 'max_execution_time = 120',
    match   => '^;?max_execution_time\s*=',
    require => Nest::Lib::Package['dev-lang/php'],
    notify  => Service['php-fpm@8.1'],
  }

  service { 'php-fpm@7.4':
    ensure  => stopped,
    enable  => false,
    require => Nest::Lib::Package['dev-lang/php'],
  }

  service { 'php-fpm@8.1':
    ensure  => running,
    enable  => true,
    require => Service['php-fpm@7.4'],
  }

  nest::lib::package { [
    'dev-php/pecl-imagick',
    'dev-php/pecl-ssh2',
  ]:
    ensure  => installed,
    require => Nest::Lib::Package['dev-lang/php'],
  }
}
