class nest::docker {
  zfs { 'docker':
    name       => "${::trusted['certname']}/docker",
    mountpoint => '/var/lib/docker',
  }

  class { 'docker':
    service_provider => 'systemd',
    require          => Zfs['docker'],
  }
}
