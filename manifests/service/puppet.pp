class nest::service::puppet {
  nest::lib::srv { 'puppet': }

  nest::lib::pod { 'puppet':
    publish => [
      '8140:8140',  # Puppet Server
      '8080:8080',  # PuppetDB dashboard
      '80:80'       # Puppetboard
    ],
  }


  #
  # Puppet Server
  #
  nest::lib::srv { 'puppet/puppetserver':
    require => Nest::Lib::Srv['puppet'],
  }
  ->
  file { [
    '/srv/puppet/puppetserver/config',
    '/srv/puppet/puppetserver/data',
  ]:
    ensure => directory,
  }
  ->
  file { '/srv/puppet/puppetserver/config/hiera.yaml':
    source => 'puppet:///modules/nest/puppet/hiera.yaml',
    notify => Service['container-puppetserver'],
  }
  ->
  nest::lib::container { 'puppetserver':
    image   => 'puppet/puppetserver',
    env     => [
      'PUPPETSERVER_HOSTNAME=puppet',
      'CA_ALLOW_SUBJECT_ALT_NAMES=true',
      'DNS_ALT_NAMES=puppet.nest',
      'PUPPETDB_SERVER_URLS=https://puppet:8081',
    ],
    pod     => 'puppet',
    volumes => [
      '/etc/puppetlabs/code:/etc/puppetlabs/code',
      '/srv/puppet/puppetserver/config:/etc/puppetlabs/puppet',
      '/srv/puppet/puppetserver/data:/opt/puppetlabs/server/data/puppetserver',
    ],
  }


  #
  # Postgres for PuppetDB
  #
  nest::lib::srv { 'puppet/postgres':
    require => Nest::Lib::Srv['puppet'],
  }
  ->
  file { '/srv/puppet/postgres/data':
    ensure => directory,
  }
  ->
  nest::lib::container { 'puppet-postgres':
    image   => 'postgres',
    env     => [
      'POSTGRES_PASSWORD=puppetdb',
      'POSTGRES_USER=puppetdb',
    ],
    pod     => 'puppet',
    volumes => ['/srv/puppet/postgres/data:/var/lib/postgresql/data'],
  }


  #
  # PuppetDB
  #
  nest::lib::srv { 'puppet/puppetdb':
    require => Nest::Lib::Srv['puppet'],
  }
  ->
  file { '/srv/puppet/puppetdb/data':
    ensure => directory,
  }
  ->
  nest::lib::container { 'puppetdb':
    image   => 'puppet/puppetdb',
    env     => [
      'CERTNAME=puppet',
      'PUPPETDB_POSTGRES_HOSTNAME=puppet',
    ],
    pod     => 'puppet',
    volumes => [
      '/srv/puppet/puppetdb/data:/opt/puppetlabs/server/data/puppetdb',
      '/srv/puppet/puppetserver/config/ssl/certs/ca.pem:/opt/puppetlabs/server/data/puppetdb/certs/certs/ca.pem',
      '/srv/puppet/puppetserver/config/ssl/certs/puppet.pem:/opt/puppetlabs/server/data/puppetdb/certs/certs/puppet.pem',
      '/srv/puppet/puppetserver/config/ssl/private_keys/puppet.pem:/opt/puppetlabs/server/data/puppetdb/certs/private_keys/puppet.pem',
    ],
  }


  #
  # Puppetboard
  #
  nest::lib::container { 'puppetboard':
    image   => 'camptocamp/puppetboard',
    env     => [
      'PUPPETDB_HOST=puppet',
      'PUPPETDB_PORT=8081',
      'PUPPETDB_SSL_VERIFY=/ca.pem',
      'PUPPETDB_CERT=/cert.pem',
      'PUPPETDB_KEY=/key.pem',
      'ENABLE_CATALOG=True',
    ],
    pod     => 'puppet',
    volumes => [
      '/srv/puppet/puppetserver/config/ssl/certs/ca.pem:/ca.pem:ro',
      '/srv/puppet/puppetserver/config/ssl/certs/puppet.pem:/cert.pem:ro',
      '/srv/puppet/puppetserver/config/ssl/private_keys/puppet.pem:/key.pem:ro',
    ],
  }
}
