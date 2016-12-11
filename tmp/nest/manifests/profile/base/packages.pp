class nest::profile::base::packages {
  package { [
    'app-admin/sysstat',
    'app-editors/vim',
    'app-misc/screen',
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
    'sys-process/lsof',
    'www-client/elinks',
  ]:
    ensure => installed,
  }

  package { 'net-misc/netkit-telnetd':
    ensure => absent,
  }

  package { 'net-misc/telnet-bsd':
    ensure => absent,
  }

  package_mask { 'sys-libs/ncurses':
    version => '>=6',
    ensure  => absent,
  }
}
