class nest::profile::base::packages {
  package { [
    'app-editors/vim',
    'net-dns/bind-tools',
    'sys-fs/dosfstools',
    'sys-block/parted',
  ]:
    ensure => installed,
  }
}
