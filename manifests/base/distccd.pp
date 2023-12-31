class nest::base::distccd {
  file { '/etc/systemd/system/distccd.service.d/00gentoo.conf':
    ensure  => absent,
  }

  file { '/etc/systemd/system/distccd.service.d/10-allowed-servers.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "[Service]\nEnvironment=\"ALLOWED_SERVERS=0.0.0.0/0\"\n",
  }
  ~>
  nest::lib::systemd_reload { 'distccd': }
  ~>
  service { 'distccd':
    enable => $nest::distcc_server,
  }

  if $nest::distcc_server {
    package { 'sys-devel/clang':
      ensure => installed,
    }
  }
}
