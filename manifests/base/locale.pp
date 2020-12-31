class nest::base::locale {
  file_line { 'locale.gen-en_US.UTF-8':
    path  => '/etc/locale.gen',
    line  => 'en_US.UTF-8 UTF-8',
    match => '^#?en_US.UTF-8 UTF-8$',
  }
  ~>
  exec { '/usr/sbin/locale-gen':
    timeout     => 0,
    refreshonly => true,
  }
  ->
  exec { '/usr/bin/eselect locale set en_US.UTF-8':
    unless => '/usr/bin/eselect --brief locale show | /bin/grep en_US.UTF-8',
  }
}
