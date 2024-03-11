class nest::base::packages {
  case $facts['os']['family'] {
    'Gentoo': {
      nest::lib::package { [
        'app-admin/helm',
        'app-admin/sysstat',
        'app-editors/vim',
        'app-misc/jq',
        'app-misc/tmux',
        'app-portage/genlop',
        'app-portage/gentoolkit',
        'dev-debug/strace',
        'dev-libs/libisoburn',
        'net-analyzer/openbsd-netcat',
        'net-dns/bind-tools',
        'net-misc/whois',
        'sys-apps/ethtool',
        'sys-apps/gptfdisk',
        'sys-apps/ipmitool',
        'sys-apps/pciutils',
        'sys-apps/pv',
        'sys-apps/usbutils',
        'sys-block/parted',
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
        nest::lib::package { 'sys-devel/lld':
          ensure => installed,
        }

        unless defined(Package['virtual/mysql']) { # mysql module
          nest::lib::package { 'dev-db/mariadb':
            ensure => installed,
            use    => '-server',
          }
        }
      }

      unless $facts['profile']['architecture'] == 'riscv' {
        # !!! [0219 21:56:00] Unsupported host arch. Must be x86_64, 386, arm, arm64, s390x or ppc64le.
        nest::lib::package { 'sys-cluster/kubectl':
          ensure => installed,
        }
      }

      unless $facts['profile']['platform'] == 'beagleboneblack' {
        nest::lib::package { 'sys-process/parallel':
          ensure => installed,
        }
      }

      if $facts['profile']['platform'] in ['milkv-pioneer', 'pine64', 'pinebookpro', 'rock4', 'rock5', 'rockpro64', 'sopine'] {
        nest::lib::package { 'sys-fs/mtd-utils':
          ensure => installed,
        }
      }

      if $facts['profile']['platform'] in ['haswell', 'milkv-pioneer', 'rock4', 'rock5'] {
        nest::lib::package { 'sys-apps/nvme-cli':
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
        'wget',
      ]:
        ensure   => installed,
        provider => 'cygwin',
      }
    }
  }
}
