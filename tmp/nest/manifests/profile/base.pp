class nest::profile::base {
  contain '::nest::profile::base::dracut'
  contain '::nest::profile::base::grub'
  contain '::nest::profile::base::firewall'
  contain '::nest::profile::base::fs'
  contain '::nest::profile::base::fstab'
  contain '::nest::profile::base::kernel'
  contain '::nest::profile::base::mta'
  contain '::nest::profile::base::network'
  contain '::nest::profile::base::openvpn'
  contain '::nest::profile::base::pam'
  contain '::nest::profile::base::portage'
  contain '::nest::profile::base::puppet'
  contain '::nest::profile::base::ssh'
  contain '::nest::profile::base::sudo'
  contain '::nest::profile::base::systemd'
  contain '::nest::profile::base::users'
  contain '::nest::profile::base::zfs'

  # Portage should be configured before any packages are installed
  Class['::nest::profile::base::portage'] ->
  Package <| |>

  # Dracut depends on systemd
  Class['::nest::profile::base::systemd'] ->
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

  # OpenVPN modifies resolvconf which is installed for NetworkManager
  Class['::nest::profile::base::network'] ->
  Class['::nest::profile::base::openvpn']

  if $::nest::libvirt {
    contain '::nest::profile::base::libvirt'

    # libvirt ebuild checks kernel config
    Class['::nest::profile::base::kernel'] ->
    Class['::nest::profile::base::libvirt']
  }
}
