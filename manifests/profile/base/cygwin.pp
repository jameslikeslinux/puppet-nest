class nest::profile::base::cygwin {
  package { [
    'cygwin',
    'cyg-get',
  ]:
    ensure => installed,
  }
}
