class nest::docker {
  zfs { 'docker':
    name       => "${::trusted['certname']}/docker",
    mountpoint => '/var/lib/docker',
  }

  class { 'docker':
    docker_ce_package_name     => 'app-emulation/docker',
    service_config             => '/etc/conf.d/docker',
    service_config_template    => 'docker/etc/sysconfig/docker.systemd.erb',
    service_overrides_template => 'nest/docker/systemd-overrides.conf.erb',
    service_provider           => 'systemd',
    require                    => Zfs['docker'],
  }

  User <| title == 'james' or title == 'bitwarden' |> {
    groups  +> 'docker',
    require +> Class['docker'],
  }
}
