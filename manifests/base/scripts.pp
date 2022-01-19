class nest::base::scripts {
  File {
    mode  => '0755',
    owner => 'root',
    group => 'root',
  }

  ['bolt', 'pdk'].each |$script| {
    file { "/usr/local/bin/${script}":
      content => epp("nest/scripts/${script}.sh.epp"),
    }
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
