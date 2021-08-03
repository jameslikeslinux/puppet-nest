class nest::base::scripts {
  File {
    mode  => '0755',
    owner => 'root',
    group => 'root',
  }

  file { '/sbin/beadm':
    source => 'puppet:///modules/nest/scripts/beadm.zsh',
  }

  file { '/usr/local/sbin/nest-install':
    source => 'puppet:///modules/nest/scripts/install.sh',
  }

  file { '/usr/local/bin/pdk':
    content => epp('nest/scripts/pdk.sh.epp'),
  }
}
