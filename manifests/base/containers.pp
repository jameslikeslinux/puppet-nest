class nest::base::containers {
  service { 'docker':
    ensure => stopped,
    enable => false,
  }
  ->
  package { 'app-emulation/docker':
    ensure => absent,
  }
  ->
  file { '/usr/bin/docker':
    ensure => absent,
  }


  zfs { 'containers':
    name       => "${facts['rpool']}/containers",
    mountpoint => '/var/lib/containers',
  }

  package { 'app-emulation/libpod':
    ensure => installed,
  }

  file {
    default:
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => Package['app-emulation/libpod'],
      before  => Service['podman.socket'],
    ;

    '/etc/containers/policy.json':
      source => 'puppet:///modules/nest/containers/policy.json',
    ;

    '/etc/containers/registries.conf':
      source => 'puppet:///modules/nest/containers/registries.conf',
    ;
  }

  service { 'podman.socket':
    enable => true,
  }

  $rootless_users = ['james']
  $subuidgid_content = $rootless_users.map |$user| {
    $index = $rootless_users.index($user)
    $subuidgid = 65536 * $index + 100000
    "${user}:${subuidgid}:65536\n"
  }.join

  file { [
    '/etc/subuid',
    '/etc/subgid',
  ]:
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $subuidgid_content,
  }
}
