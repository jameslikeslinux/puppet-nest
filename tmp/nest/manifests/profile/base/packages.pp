class nest::profile::base::packages {
  package { [
    'app-admin/sysstat',
    'app-editors/vim',
    'app-misc/tmux',
    'app-portage/gentoolkit',
    'dev-libs/libisoburn',
    'dev-util/strace',
    'net-analyzer/openbsd-netcat',
    'net-dns/bind-tools',
    'net-misc/whois',
    'sys-block/parted',
    'sys-fs/dosfstools',
    'sys-fs/mtools',
    'sys-fs/squashfs-tools',
    'sys-process/htop',
    'sys-process/lsof',
    'www-client/elinks',
  ]:
    ensure => installed,
  }

  package { 'app-misc/screen':
    ensure => absent,
  }
}
