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
}
