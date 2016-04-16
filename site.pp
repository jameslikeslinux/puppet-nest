Service {
  provider => systemd,
}

stage { 'pre': } -> Stage['main']

class { 'nest':
  stage => 'pre',
}

class { '::nest::firewall::pre':
  stage => 'pre',
}

class { '::nest::firewall::post': }

Firewall {
  require => Class['::nest::firewall::pre'],
  before  => Class['::nest::firewall::post'],
}

hiera_include('classes')
