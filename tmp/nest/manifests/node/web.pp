class nest::node::web {
  include '::nest::apache'
  include '::nest::mysql'
  include '::nest::php'

  zfs { 'srv':
    name       => "${::trusted['certname']}/srv",
    mountpoint => '/srv',
  }

  zfs { 'srv/www':
    name       => "${::trusted['certname']}/srv/www",
    mountpoint => '/srv/www',
    require    => Zfs['srv'],
  }

  zfs { 'srv/www/thestaticvoid.com':
    name       => "${::trusted['certname']}/srv/www/thestaticvoid.com",
    mountpoint => '/srv/www/thestaticvoid.com',
    require    => Zfs['srv/www'],
  }
}
