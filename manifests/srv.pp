define nest::srv (
  Boolean $zfs = true,
) {
  ensure_resource('zfs', 'srv', {
    'name'       => "${::trusted['certname']}/srv",
    'mountpoint' => '/srv',
  })

  if $zfs {
    zfs { "srv/${name}":
      name       => "${::trusted['certname']}/srv/${name}",
      mountpoint => "/srv/${name}",
    }
  } else {
    file { "/srv/${name}":
      ensure  => directory,
      require => Zfs['srv'],
    }
  }
}
