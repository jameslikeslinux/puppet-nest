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
      contain '::nest::base::bootloader'
      contain '::nest::base::crossdev'
      contain '::nest::base::distcc'
      contain '::nest::base::distccd'
      contain '::nest::base::dracut'
      contain '::nest::base::fail2ban'
      contain '::nest::base::firewall'
      contain '::nest::base::firmware'
      contain '::nest::base::fs'
      contain '::nest::base::fstab'
      contain '::nest::base::kernel'
      contain '::nest::base::mta'
      contain '::nest::base::network'
      contain '::nest::base::openvpn'
      contain '::nest::base::plymouth'
      contain '::nest::base::portage'
      contain '::nest::base::sudo'
      contain '::nest::base::systemd'
      contain '::nest::base::timesyncd'
      contain '::nest::base::zfs'
      contain '::nest::base::zram'

      # Setup distcc before portage, but distccd needs systemd, which is
      # installed after portage is configured.
      Class['::nest::base::distcc']
      -> Class['::nest::base::portage']
      -> Class['::nest::base::distccd']

      # Portage should be configured before any packages are installed/changed
      Class['::nest::base::portage'] -> Package <| title != 'sys-devel/distcc' and
                                                   title != 'dev-vcs/git' and
                                                   title != 'app-admin/eselect' |>
      Class['::nest::base::portage'] -> Nest::Lib::Portage::Package_use <| |>

      # Portage configuration (profile) responsible for installing systemd
      Class['::nest::base::portage']
      -> Class['::nest::base::systemd']

      # Dracut depends on systemd/console setup
      Class['::nest::base::systemd']
      ~> Class['::nest::base::dracut']

      # Rebuild initramfs and reconfigure bootloader after kernel changes
      Class['::nest::base::kernel']
      ~> Class['::nest::base::dracut']
      ~> Class['::nest::base::bootloader']

      # Rebuild initramfs after firmware changes
      Class['::nest::base::firmware']
      ~> Class['::nest::base::dracut']

      # Rebuild initramfs after ZFS changes
      Class['::nest::base::kernel']
      -> Class['::nest::base::zfs']
      ~> Class['::nest::base::dracut']

      # Rebuild initramfs after plymouth changes
      Class['::nest::base::plymouth']
      ~> Class['::nest::base::dracut']

      # Sudo requires configured MTA
      Class['::nest::base::mta']
      -> Class['::nest::base::sudo']

      # Dracut liveimg depends on dhcp, pulled in by network class
      Class['::nest::base::network']
      -> Class['::nest::base::dracut']

      # OpenVPN modifies resolvconf which is installed for NetworkManager
      Class['::nest::base::network']
      -> Class['::nest::base::openvpn']

      if $::nest::libvirt {
        contain '::nest::base::libvirt'

        # libvirt ebuild checks kernel config
        Class['::nest::base::kernel']
        -> Class['::nest::base::libvirt']
      }
    }

    'windows': {
      contain '::nest::base::cygwin'
      Class['::nest::base::cygwin'] -> Package <| provider == 'cygwin' and title != 'cygrunsrv' |>

      # The users class manages my cygwin home directory
      Class['::nest::base::cygwin'] -> Class['::nest::base::users']
    }
  }
}
