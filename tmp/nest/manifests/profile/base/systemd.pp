class nest::profile::base::systemd {
  class use {
    package_use { 'sys-apps/systemd':
      use => 'cryptsetup',
    }
  }

  include '::nest::profile::base::systemd::use'

  file { '/etc/hostname':
    content => "${::trusted['certname']}\n",
  }

  file { '/etc/localtime':
    ensure => link,
    target => '/usr/share/zoneinfo/America/New_York',
  }

  augeas { 'nsswitch-hosts-add-myhostname':
    context => '/files/etc/nsswitch.conf',
    changes => "set database[. = 'hosts']/service[last()+1] myhostname",
    onlyif  => "get database[. = 'hosts']/service[last()] != 'myhostname'",
  }

  file_line { 'locale.gen-en_US.UTF-8':
    path  => '/etc/locale.gen',
    line  => 'en_US.UTF-8 UTF-8',
    match => '^#en_US.UTF-8 UTF-8$',
  }

  exec { '/usr/sbin/locale-gen':
    refreshonly => true,
    subscribe   => File_line['locale.gen-en_US.UTF-8'],
  }

  file { '/etc/locale.conf':
    content => "LANG=en_US.utf8\n",
    require => Exec['/usr/sbin/locale-gen'],
  }

  file { '/etc/issue':
    content => "\nThis is \\n (\\s \\m \\r) \\t\n\n",
  }
}
