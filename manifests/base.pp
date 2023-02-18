class nest::base {
  contain 'nest::base::puppet'
  contain 'nest::base::git'
  contain 'nest::base::openvpn'
  contain 'nest::base::packages'
  contain 'nest::base::qemu'
  contain 'nest::base::ssh'
  contain 'nest::base::syslog'
  contain 'nest::base::users'
  contain 'nest::base::vmware'

  # Git should be installed before managing any Vcsrepos
  Class['nest::base::git'] -> Vcsrepo <| provider == git |>

  case $facts['os']['family'] {
    'Gentoo': {
      contain 'nest::base::branding'
      contain 'nest::base::cli'
      contain 'nest::base::console'
      contain 'nest::base::containers'
      contain 'nest::base::distcc'
      contain 'nest::base::distccd'
      contain 'nest::base::fail2ban'
      contain 'nest::base::firewall'
      contain 'nest::base::fs'
      contain 'nest::base::gentoo'
      contain 'nest::base::hosts'
      contain 'nest::base::locale'
      contain 'nest::base::mta'
      contain 'nest::base::network'
      contain 'nest::base::portage'
      contain 'nest::base::scripts'
      contain 'nest::base::sudo'
      contain 'nest::base::systemd'
      contain 'nest::base::timesyncd'
      contain 'nest::base::wifi'
      contain 'nest::base::zfs'

      if $facts['build'] in [undef, 'stage2', 'stage3', 'kernel'] {
        contain 'nest::base::dracut'
        contain 'nest::base::firmware'
        contain 'nest::base::fstab'
        contain 'nest::base::kernel'
        contain 'nest::base::plymouth'

        # OS release info is used in the initramfs
        Class['nest::base::branding']
        ~> Class['nest::base::dracut']

        # Dracut depends on console fonts and keymaps
        Class['nest::base::console']
        ~> Class['nest::base::dracut']

        # Kernel builds Device Tree files used by firmware,
        # firmware pulls in files to be included in initramfs
        Class['nest::base::kernel']
        -> Class['nest::base::firmware']
        ~> Class['nest::base::dracut']

        # Rebuild initramfs after plymouth changes
        Class['nest::base::plymouth']
        ~> Class['nest::base::dracut']

        # Rebuild initramfs after ZFS changes
        Class['nest::base::zfs']
        ~> Class['nest::base::dracut']

        # Root password hash contained in initramfs needs to be updated
        User['root']
        ~> Class['nest::base::dracut']

        # Bootloaders are host-specific
        if $facts['build'] in [undef, 'stage3', 'kernel'] {
          contain 'nest::base::bootloader'
          contain 'nest::base::kexec'

          Class['nest::base::dracut']
          ~> Class['nest::base::bootloader']

          if $nest::kexec {
            Class['nest::base::bootloader']
            ~> Class['nest::base::kexec']
          }
        }
      }

      # Subuid/subgid maps override automatic entries from useradd
      Class['nest::base::users']
      -> Class['nest::base::containers']

      # Gentoo news might send mail
      Class['nest::base::mta']
      -> Class['nest::base::gentoo']

      # Sudo requires configured MTA
      Class['nest::base::mta']
      -> Class['nest::base::sudo']

      # Setup distcc before portage
      Class['nest::base::distcc']
      -> Class['nest::base::portage']

      # Portage should be configured before any packages are installed/changed
      Class['nest::base::portage'] -> Nest::Lib::Package_use <||>
      Class['nest::base::portage'] -> Package <| (provider == 'portage' or provider == undef) and
                                                  title != 'dev-vcs/git' and
                                                  title != 'sys-devel/distcc' |>

      # Package installation can result in unread news
      Package <| provider == 'portage' or provider == undef |>
      -> Class['nest::base::gentoo']
    }

    'windows': {
      contain 'nest::base::cygwin'
      Class['nest::base::cygwin'] -> Package <| provider == 'cygwin' and title != 'cygrunsrv' |>

      # The users class manages my cygwin home directory
      Class['nest::base::cygwin'] -> Class['nest::base::users']
    }
  }
}
