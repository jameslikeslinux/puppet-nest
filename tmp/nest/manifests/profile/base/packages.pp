class nest::profile::base::packages {
  package { [
    'app-editors/vim',
    'sys-fs/dosfstools',
    'sys-block/parted',
  ]:
    ensure => installed,
  }
}
