class nest::profile::base {
  contain '::nest::profile::base::systemd'
  contain '::nest::profile::base::kernel'
  contain '::nest::profile::base::dracut'
  contain '::nest::profile::base::grub'
  contain '::nest::profile::base::zfs'
  contain '::nest::profile::base::fstab'
  contain '::nest::profile::base::pam'

  # Dracut depends on systemd
  Class['::nest::profile::base::systemd'] ->
  Class['::nest::profile::base::dracut']

  Class['::nest::profile::base::kernel'] ~>
  Class['::nest::profile::base::dracut'] ~>
  Class['::nest::profile::base::grub']

  Class['::nest::profile::base::kernel'] ->
  Class['::nest::profile::base::zfs'] ~>
  Class['::nest::profile::base::dracut']
}
