define nest::lib::srv (
  Boolean          $zfs   = true,
  Optional[String] $mode  = undef,
  Optional[String] $owner = undef,
  Optional[String] $group = undef,
) {
  ensure_resource('zfs', 'srv', {
    'name'       => "${facts['rpool']}/srv",
    'mountpoint' => '/srv',
  })

  if $zfs {
    zfs { "srv/${name}":
      name       => "${facts['rpool']}/srv/${name}",
      mountpoint => "/srv/${name}",
      require    => Zfs['srv'],
      before     => File["/srv/${name}"],
    }
  }

  file { "/srv/${name}":
    ensure  => directory,
    mode    => $mode,
    owner   => $owner,
    group   => $group,
    require => Zfs['srv'],
  }
}
