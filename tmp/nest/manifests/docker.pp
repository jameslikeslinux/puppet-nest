class nest::docker {
  zfs { 'docker':
    name       => "${::trusted['certname']}/docker",
    mountpoint => '/var/lib/docker',
  }
}
