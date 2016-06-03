class nest::profile::base::packages {
  package { 'sys-block/parted':
    ensure => installed,
  }
}
