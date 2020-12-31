class nest::base::locale {
  file_line { 'locale.gen-en_US.UTF-8':
    path  => '/etc/locale.gen',
    line  => 'en_US.UTF-8 UTF-8',
    match => '^#?en_US.UTF-8 UTF-8$',
  }

  exec { '/usr/sbin/locale-gen':
    timeout     => 0,
    refreshonly => true,
    subscribe   => File_line['locale.gen-en_US.UTF-8'],
  }

  file { '/etc/locale.conf':
    content => "LANG=en_US.UTF-8\n",
    require => Exec['/usr/sbin/locale-gen'],
  }
}
