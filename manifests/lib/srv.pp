define nest::lib::srv (
  Nest::Ensure     $ensure = 'present',
  Optional[String] $mode   = undef,
  Optional[String] $owner  = undef,
  Optional[String] $group  = undef,
  Optional[Array]  $ignore = undef,
  Boolean          $purge  = false,
  Boolean          $zfs    = true,
) {
  unless $facts['is_container'] {
    ensure_resource('zfs', 'srv', {
      name       => "${facts['rpool']}/srv",
      mountpoint => '/srv',
      before     => File['/srv'],
    })

    if $zfs {
      zfs { "srv/${name}":
        ensure     => $ensure,
        name       => "${facts['rpool']}/srv/${name}",
        mountpoint => "/srv/${name}",
        require    => Zfs['srv'],
        before     => File["/srv/${name}"],
      }
    }
  }

  ensure_resource('file', '/srv', {
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  })

  if $ensure == present {
    if $purge {
      $purge_args = {
        ignore  => $ignore,
        purge   => $purge,
        recurse => true,
        force   => true,
      }
    } else {
      $purge_args = {}
    }

    file { "/srv/${name}":
      ensure => directory,
      mode   => $mode,
      owner  => $owner,
      group  => $group,
      *      => $purge_args,
    }
  } else {
    file { "/srv/${name}":
      ensure => absent,
      force  => true,
    }
  }
}
