class nest::node::puppet {
  nest::lib::srv { 'puppetserver': }

  file { '/srv/puppetserver/hiera.yaml':
    source  => 'puppet:///modules/nest/puppet/hiera.yaml',
    require => Nest::Lib::Srv['puppetserver'],
  }

  package { 'r10k':
    ensure => installed,
  }

  file { '/etc/puppetlabs/r10k':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  file { '/etc/puppetlabs/r10k/r10k.yaml':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/puppet/r10k.yaml',
  }

  file { '/etc/eyaml':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  $eyaml_config = @(EOT)
    ---
    pkcs7_private_key: '/srv/puppetserver/ssl/ca/ca_key.pem'
    pkcs7_public_key: '/srv/puppetserver/ssl/certs/ca.pem'
    | EOT

  file { '/etc/eyaml/config.yaml':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $eyaml_config,
  }
}
