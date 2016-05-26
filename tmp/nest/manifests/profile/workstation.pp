class nest::profile::workstation {
  contain '::nest::profile::workstation::chromium'
  contain '::nest::profile::workstation::cursor'
  contain '::nest::profile::workstation::firefox'
  contain '::nest::profile::workstation::fonts'
  contain '::nest::profile::workstation::mpd'
  contain '::nest::profile::workstation::plasma'
  contain '::nest::profile::workstation::policykit'
  contain '::nest::profile::workstation::thunderbird'
  contain '::nest::profile::workstation::xorg'

  # Plasma pulls in xorg-drivers which builds nvidia-drivers which requires
  # a built kernel and needs to come before building the initramfs.
  Class['::nest::profile::base::kernel'] ->
  Class['::nest::profile::workstation::plasma'] ->
  Class['::nest::profile::base::dracut']

  # Plasma installs xorg-server, so we don't need to manage it separately
  Class['::nest::profile::workstation::plasma'] ->
  Class['::nest::profile::workstation::xorg']

  # Plasma installs default cursors which we want to replace
  Class['::nest::profile::workstation::plasma'] ->
  Class['::nest::profile::workstation::cursor']

  # PolicyKit is pulled in by the profile
  Class['::nest::profile::base::portage'] ->
  Class['::nest::profile::workstation::policykit']
}
