class nest::base::packages {
  case $facts['os']['family'] {
    'Gentoo': {
      package { [
        'app-admin/sysstat',
        'app-editors/vim',
        'app-misc/tmux',
        'app-portage/genlop',
        'app-portage/gentoolkit',
        'dev-libs/libisoburn',
        'dev-util/strace',
        'net-analyzer/openbsd-netcat',
        'net-dns/bind-tools',
        'net-misc/whois',
        'sys-apps/ethtool',
        'sys-apps/ipmitool',
        'sys-apps/pv',
        'sys-apps/usbutils',
        'sys-block/parted',
        'sys-cluster/kubectl',
        'sys-fs/dosfstools',
        'sys-fs/mtools',
        'sys-fs/squashfs-tools',
        'sys-libs/nss_wrapper',
        'sys-process/htop',
        'sys-process/iotop',
        'sys-process/lsof',
        'www-client/elinks',
        'x11-misc/xsel',
      ]:
        ensure => installed,
      }

      unless $facts['profile']['platform'] == 'beagleboneblack' {
        package { 'sys-process/parallel':
          ensure => installed,
        }
      }

      if $facts['profile']['platform'] in ['pinebookpro', 'rock5', 'sopine'] {
        package { 'sys-fs/mtd-utils':
          ensure => installed,
        }
      }
    }

    'windows': {
      package { [
        'cygutils-extra',
        'nc',
        'procps-ng',
        'tmux',
        'vim',
      ]:
        ensure   => installed,
        provider => 'cygwin',
      }
    }
  }
}
