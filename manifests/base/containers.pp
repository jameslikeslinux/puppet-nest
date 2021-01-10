class nest::base::containers {
  unless $facts['is_container'] {
    zfs { 'containers':
      name       => "${facts['rpool']}/containers",
      mountpoint => '/var/lib/containers',
    }
  }

  package { [
    'app-emulation/crun',
    'app-emulation/libpod',
  ]:
    ensure => installed,
  }
  ->
  file {
    default:
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
    ;

    '/etc/containers/containers.conf':
      source => 'puppet:///modules/nest/containers/containers.conf'
    ;

    '/etc/containers/policy.json':
      source => 'puppet:///modules/nest/containers/policy.json',
    ;

    '/etc/containers/registries.conf':
      source => 'puppet:///modules/nest/containers/registries.conf',
    ;

    '/etc/systemd/system/podman.service.d':
      ensure => directory,
    ;

    '/etc/systemd/system/podman.service.d/10-delegate.conf':
      content => "[Service]\nDelegate=yes\n",
      notify  => Nest::Lib::Systemd_reload['containers'],
    ;
  }
  ->
  nest::lib::systemd_reload { 'containers': }
  ->
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
