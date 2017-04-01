class nest::php {
  nest::portage::package_use { 'app-eselect/eselect-php':
    use => 'fpm',
  }

  nest::portage::package_use { 'dev-lang/php':
    use => ['curl', 'fpm', 'gd', 'mysql', 'mysqli', 'soap'],
  }

  package { 'dev-lang/php':
    ensure  => installed,

    # The dependency on Nest::Portage::Package_use['dev-lang/php'] is implied;
    # eselect-php needs to use fpm too
    require => Nest::Portage::Package_use['app-eselect/eselect-php'],
  }

  service { 'php-fpm@7.0':
    enable  => true,
    require => Package['dev-lang/php'],
  }

  portage::makeconf { 'php_targets':
    content => 'php7-0',
  }

  package { 'dev-php/pecl-ssh2':
    ensure => installed,
  }
}
