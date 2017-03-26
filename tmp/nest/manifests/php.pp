class nest::php {
  nest::portage::package_use { 'dev-lang/php':
    use => 'fpm',
  }

  package { 'dev-lang/php':
    ensure => installed,
  }

  service { 'php-fpm@7.0':
    enable  => true,
    require => Package['dev-lang/php'],
  }
}
