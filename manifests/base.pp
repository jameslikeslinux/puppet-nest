class nest::base {
  contain '::nest::base::puppet'
  contain '::nest::base::git'
  contain '::nest::base::packages'
  contain '::nest::base::qemu'
  contain '::nest::base::ssh'
  contain '::nest::base::users'

  # Git should be installed before managing any Vcsrepos
  Class['::nest::base::git'] -> Vcsrepo <| provider == git |>

  case $facts['osfamily'] {
    'Gentoo': {
      contain '::nest::base::containers'
      contain '::nest::base::distcc'
      contain '::nest::base::distccd'
      contain '::nest::base::fail2ban'
      contain '::nest::base::firewall'
      contain '::nest::base::fs'
      contain '::nest::base::hosts'
      contain '::nest::base::locale'
      contain '::nest::base::mta'
      contain '::nest::base::network'
      contain '::nest::base::openvpn'
      contain '::nest::base::portage'
      contain '::nest::base::scripts'
      contain '::nest::base::sudo'
      contain '::nest::base::systemd'
      contain '::nest::base::timesyncd'
      contain '::nest::base::zfs'

      if $facts['build'] in [undef, 'stage2', 'stage3', 'kernel'] {
        contain '::nest::base::dracut'
        contain '::nest::base::firmware'
        contain '::nest::base::fstab'
        contain '::nest::base::kernel'
        contain '::nest::base::plymouth'

        # Rebuild initramfs and reconfigure bootloader after kernel changes
        Class['::nest::base::kernel']
        ~> Class['::nest::base::dracut']

        # Kernel builds Device Tree files used by firmware,
        # firmware pulls in files to be included in initramfs
        Class['::nest::base::kernel']
        -> Class['::nest::base::firmware']
        ~> Class['::nest::base::dracut']

        # Dracut liveimg depends on dhcp, pulled in by network class
        Class['::nest::base::network']
        -> Class['::nest::base::dracut']

        # Rebuild initramfs after plymouth changes
        Class['::nest::base::plymouth']
        ~> Class['::nest::base::dracut']

        # Dracut depends on systemd/console setup
        Class['::nest::base::systemd']
        ~> Class['::nest::base::dracut']

        # Rebuild initramfs after ZFS changes
        Class['::nest::base::zfs']
        ~> Class['::nest::base::dracut']

        # Bootloaders are host-specific
        if $facts['build'] in [undef, 'stage3', 'kernel'] {
          contain '::nest::base::bootloader'

          Class['::nest::base::dracut']
          ~> Class['::nest::base::bootloader']
        }
      }

      # Subuid/subgid maps override automatic entries from useradd
      Class['::nest::base::users']
      -> Class['::nest::base::containers']

      # Sudo requires configured MTA
      Class['::nest::base::mta']
      -> Class['::nest::base::sudo']

      # OpenVPN modifies resolvconf which is installed for NetworkManager
      Class['::nest::base::network']
      -> Class['::nest::base::openvpn']

      # Setup distcc before portage
      Class['::nest::base::distcc']
      -> Class['::nest::base::portage']

      # Portage should be configured before any packages are installed/changed
      Class['::nest::base::portage'] -> Nest::Lib::Package_use <||>
      Class['::nest::base::portage'] -> Package <| (provider == 'portage' or provider == undef) and
                                                   title != 'dev-vcs/git' and
                                                   title != 'sys-devel/distcc' |>
    }

    'windows': {
      contain '::nest::base::cygwin'
      Class['::nest::base::cygwin'] -> Package <| provider == 'cygwin' and title != 'cygrunsrv' |>

      # The users class manages my cygwin home directory
      Class['::nest::base::cygwin'] -> Class['::nest::base::users']
    }
  }
}
