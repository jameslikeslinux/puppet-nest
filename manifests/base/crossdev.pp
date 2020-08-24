class nest::base::crossdev {
  if $::platform == 'pinebookpro' {
    package { 'sys-devel/crossdev':
      ensure => installed,
    }
    ->
    exec { '/usr/bin/crossdev --stable -s1 -t arm-none-eabi':
      creates => '/usr/bin/arm-none-eabi-gcc',
      timeout => 0,
    }
  }
}
