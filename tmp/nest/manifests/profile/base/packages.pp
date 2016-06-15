class nest::profile::base::packages {
  package { [
    'app-admin/sysstat',
    'app-editors/vim',
    'app-misc/screen',
    'app-portage/gentoolkit',
    'dev-libs/libisoburn',
    'net-dns/bind-tools',
    'sys-fs/dosfstools',
    'sys-fs/squashfs-tools',
    'sys-block/parted',
    'www-client/elinks',
  ]:
    ensure => installed,
  }
}
