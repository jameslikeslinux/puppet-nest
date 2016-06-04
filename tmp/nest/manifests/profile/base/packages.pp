class nest::profile::base::packages {
  package { [
    'app-editors/vim',
    'sys-block/parted',
  ]:
    ensure => installed,
  }
}
