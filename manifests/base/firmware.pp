class nest::base::firmware {
  package { 'sys-kernel/linux-firmware':
    ensure => installed,
  }

  file { '/lib/firmware':
    ensure  => 'directory',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    recurse => true,
    source  => 'puppet:///modules/nest/firmware',
  }
}
