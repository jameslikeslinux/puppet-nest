class nest::profile::workstation {
  contain '::nest::profile::workstation::firefox'
  contain '::nest::profile::workstation::plasma'

  # Plasma pulls in xorg-drivers which builds nvidia-drivers which requires
  # a built kernel and needs to come before building the initramfs.
  Class['::nest::profile::base::kernel'] ->
  Class['::nest::profile::workstation::plasma'] ->
  Class['::nest::profile::base::dracut']
}
