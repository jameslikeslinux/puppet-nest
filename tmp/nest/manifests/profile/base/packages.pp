class nest::profile::base::packages {
  package { [
    'app-editors/vim',
    'app-portage/gentoolkit',
    'net-dns/bind-tools',
    'sys-fs/dosfstools',
    'sys-block/parted',
    'www-client/elinks',
  ]:
    ensure => installed,
  }
}
