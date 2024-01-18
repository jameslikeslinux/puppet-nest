class nest::base::packages {
  case $facts['os']['family'] {
    'Gentoo': {
      package { [
        'app-admin/helm',
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
        'sys-fs/exfatprogs',
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

      unless $facts['profile']['architecture'] == 'arm' {
        package { 'sys-devel/lld':
          ensure => installed,
        }

        unless defined(Package['virtual/mysql']) {
          nest::lib::package { 'virtual/mysql':
            ensure => installed,
            use    => '-server',
          }
        }
      }

      unless $facts['profile']['platform'] == 'beagleboneblack' {
        package { 'sys-process/parallel':
          ensure => installed,
        }
      }

      if $facts['profile']['platform'] in ['pine64', 'pinebookpro', 'rock5', 'rockpro64', 'sopine'] {
        package { 'sys-fs/mtd-utils':
          ensure => installed,
        }
      }

      if $facts['profile']['platform'] in ['haswell', 'rock5'] {
        package { 'sys-apps/nvme-cli':
          ensure => installed,
        }
      }

      # Python is part of Gentoo base
      # Define this resource for compatibility with puppet-python module
      package { 'python':
        name => 'dev-lang/python',
      }
    }

    'windows': {
      package { [
        'cygutils-extra',
        'netcat',
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
