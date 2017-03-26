class nest::node::web {
  include '::nest::apache'
  include '::nest::mysql'
  include '::nest::php'

  zfs { 'srv':
    name       => "${::trusted['certname']}/srv",
    mountpoint => '/srv',
  }

  zfs { 'srv/www':
    name       => "${::trusted['certname']}/srv/plex",
    mountpoint => '/srv/www',
    require    => Zfs['srv'],
  }
}
