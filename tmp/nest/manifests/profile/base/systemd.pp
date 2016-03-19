class nest::profile::base::systemd {
  nest::portage::package_use { 'sys-apps/systemd':
    use => 'cryptsetup',
  }

  # See: https://wiki.gentoo.org/wiki/Systemd#.2Fetc.2Fmtab
  file { '/etc/mtab':
    ensure => link,
    target => '/proc/self/mounts',
  }

  file { '/etc/hostname':
    content => "${trusted['certname']}\n",
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
