define nest::lib::srv (
  Boolean $zfs = true,
) {
  ensure_resource('zfs', 'srv', {
    'name'       => "${facts['rpool']}/srv",
    'mountpoint' => '/srv',
  })

  if $zfs {
    zfs { "srv/${name}":
      name       => "${facts['rpool']}/srv/${name}",
      mountpoint => "/srv/${name}",
    }
  } else {
    file { "/srv/${name}":
      ensure  => directory,
      require => Zfs['srv'],
    }
  }
}
