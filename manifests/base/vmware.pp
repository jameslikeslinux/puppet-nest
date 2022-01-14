class nest::base::vmware {
  case $facts['osfamily'] {
    'Gentoo': {
      if $facts['virtual'] == 'vmware' {
        nest::lib::package { 'app-emulation/open-vm-tools':
          ensure => installed,
          use    => 'gtkmm',
        }
        ->
        service { 'vmtoolsd':
          enable => true,
        }

        # For copy/paste and drag-and-drop
        # See: https://kb.vmware.com/s/article/74671
        file { '/etc/systemd/system/run-vmblock\x2dfuse.mount':
          mode   => '0644',
          owner  => 'root',
          group  => 'root',
          source => 'puppet:///modules/nest/vmware/run-vmblock\x2dfuse.mount',
        }
        ~>
        nest::lib::systemd_reload { 'vmware': }
        ->
        service { 'run-vmblock\x2dfuse.mount':
          enable => true,
        }
      }
    }

    'windows': {
      # not implemented
    }
  }
}
