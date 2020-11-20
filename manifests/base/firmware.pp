class nest::base::firmware {
  file { '/lib/firmware':
    ensure  => 'directory',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    recurse => true,
    source  => 'puppet:///modules/nest/firmware',
  }
}
