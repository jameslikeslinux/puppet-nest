class nest::base::lvm {
  package { 'sys-fs/lvm2':
    ensure => absent,
  }
}
