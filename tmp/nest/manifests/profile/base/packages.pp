class nest::profile::base::packages {
  package { [
    'app-admin/sysstat',
    'app-editors/vim',
    'app-misc/screen',
    'app-portage/gentoolkit',
    'dev-libs/libisoburn',
    'net-dns/bind-tools',
    'sys-block/parted',
    'sys-fs/dosfstools',
    'sys-fs/mtools',
    'sys-fs/squashfs-tools',
    'www-client/elinks',
  ]:
    ensure => installed,
  }
}
