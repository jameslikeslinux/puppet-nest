class nest::php {
  nest::portage::package_use { [
    'app-eselect/eselect-php',
    'dev-lang/php',
  ]:
    use => 'fpm',
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
}
