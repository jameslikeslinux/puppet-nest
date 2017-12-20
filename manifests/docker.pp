class nest::docker {
  zfs { 'docker':
    name       => "${::trusted['certname']}/docker",
    mountpoint => '/var/lib/docker',
  }

  class { 'docker':
    docker_ce_package_name => 'app-emulation/docker',
    service_provider       => 'systemd',
    require                => Zfs['docker'],
  }

  User <| title == 'james' |> {
    groups  +> 'docker',
    require +> Class['docker'],
  }
}
