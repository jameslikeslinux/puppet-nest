class nest::base::scripts {
  File {
    mode  => '0755',
    owner => 'root',
    group => 'root',
  }

  file { '/usr/local/bin/pdk':
    content => epp('nest/scripts/pdk.sh.epp'),
  }


  #
  # XXX Cleanup
  #
  file { [
    '/sbin/beadm',
    '/usr/local/sbin/nest-install',
  ]:
    ensure => absent,
  }
}
