class nest::profile::setup {
  contain '::nest::profile::setup::kernel'
  contain '::nest::profile::setup::portage'
  contain '::nest::profile::setup::root'

  # Configure Portage before installing/building kernel package
  Class['::nest::profile::setup::portage'] ->
  Class['::nest::profile::setup::kernel']
}
