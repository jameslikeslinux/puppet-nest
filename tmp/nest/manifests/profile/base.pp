class nest::profile::base {
  contain '::nest::profile::base::distcc'
  contain '::nest::profile::base::distccd'
  contain '::nest::profile::base::dracut'
  contain '::nest::profile::base::grub'
  contain '::nest::profile::base::firewall'
  contain '::nest::profile::base::fs'
  contain '::nest::profile::base::fstab'
  contain '::nest::profile::base::kernel'
  contain '::nest::profile::base::mta'
  contain '::nest::profile::base::network'
  contain '::nest::profile::base::openvpn'
  contain '::nest::profile::base::packages'
  contain '::nest::profile::base::policykit'
  contain '::nest::profile::base::portage'
  contain '::nest::profile::base::puppet'
  contain '::nest::profile::base::ssh'
  contain '::nest::profile::base::sudo'
  contain '::nest::profile::base::systemd'
  contain '::nest::profile::base::users'
  contain '::nest::profile::base::zfs'

  # Setup distcc before portage, but distccd needs systemd, which is
  # installed after portage is configured.
  Class['::nest::profile::base::distcc'] ->
  Class['::nest::profile::base::portage'] ->
  Class['::nest::profile::base::distccd']

  # Portage should be configured before any packages are installed/changed
  Class['::nest::profile::base::portage'] -> Package <| title != 'sys-devel/distcc' |>
  Class['::nest::profile::base::portage'] -> Nest::Portage::Package_use <| |>

  # Dracut depends on systemd/console setup
  Class['::nest::profile::base::systemd'] ~>
  Class['::nest::profile::base::dracut']

  # Rebuild initramfs and reconfigure GRUB after kernel changes
  Class['::nest::profile::base::kernel'] ~>
  Class['::nest::profile::base::dracut'] ~>
  Class['::nest::profile::base::grub']

  # Rebuild initramfs after ZFS changes
  Class['::nest::profile::base::kernel'] ->
  Class['::nest::profile::base::zfs'] ~>
  Class['::nest::profile::base::dracut']

  # Sudo requires configured MTA
  Class['::nest::profile::base::mta'] ->
  Class['::nest::profile::base::sudo']

  # Dracut liveimg depends on dhcp, pulled in by network class
  Class['::nest::profile::base::network'] ->
  Class['::nest::profile::base::dracut']

  # OpenVPN modifies resolvconf which is installed for NetworkManager
  Class['::nest::profile::base::network'] ->
  Class['::nest::profile::base::openvpn']

  # PolicyKit is pulled in by NetworkManager
  Class['::nest::profile::base::network'] ->
  Class['::nest::profile::base::policykit']

  if $::nest::libvirt {
    contain '::nest::profile::base::libvirt'

    # libvirt ebuild checks kernel config
    Class['::nest::profile::base::kernel'] ->
    Class['::nest::profile::base::libvirt']
  }
}
