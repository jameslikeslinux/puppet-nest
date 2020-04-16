class nest::base::lvm {
  package { 'sys-fs/lvm2':
    ensure => installed,
  }

  file_line { 'lvm.conf-global_filter-zvol':
    path    => '/etc/lvm/lvm.conf',
    line    => "\tglobal_filter = [ \"r|/dev/zd.*|\" ]",
    match   => 'global_filter = ',
    require => Package['sys-fs/lvm2'],
  }
}
