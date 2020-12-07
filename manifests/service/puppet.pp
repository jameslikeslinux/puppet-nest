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
      'PUPPETDB_POSTGRES_HOSTNAME=localhost',
    ],
    pod     => 'puppet',
    volumes => [
      '/srv/puppet/puppetdb/data:/opt/puppetlabs/server/data/puppetdb',
    ],
  }


  #
  # Puppetboard
  #
  nest::lib::container { 'puppetboard':
    image => 'camptocamp/puppetboard',
    env   => [
      'ENABLE_CATALOG=True',
    ],
    pod   => 'puppet',
  }
}
