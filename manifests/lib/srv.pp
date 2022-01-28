define nest::lib::srv (
  Optional[String] $mode  = undef,
  Optional[String] $owner = undef,
  Optional[String] $group = undef,
  Boolean          $zfs   = true,
) {
  unless $facts['is_container'] {
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

    Zfs['srv']
    -> File["/srv/${name}"]
  }

  file { "/srv/${name}":
    ensure => directory,
    mode   => $mode,
    owner  => $owner,
    group  => $group,
  }
}
