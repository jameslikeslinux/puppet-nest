class nest::profile::base::pam {
  nest::portage::package_use { 'sys-auth/pambase':
    use => 'pam_ssh',
  }
}
