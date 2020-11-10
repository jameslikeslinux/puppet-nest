class nest::base::ssh {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::lib::portage::package_use { 'net-misc/openssh':
        use => 'kerberos',
      }

      package { 'net-misc/openssh':
        ensure => installed,
      }

      file_line {
        default:
          path    => '/etc/ssh/sshd_config',
          require => Package['net-misc/openssh'],
          notify  => Service['sshd'];

        'sshd_config-ChallengeResponseAuthentication':
          line  => 'ChallengeResponseAuthentication no',
          match => '^#?ChallengeResponseAuthentication ';

        'sshd_config-X11Forwarding':
          line  => 'X11Forwarding yes',
          match => '^#?X11Forwarding ';
      }

      service { 'sshd':
        enable => true,
      }

      file { '/etc/systemd/user/ssh-agent.service':
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/nest/ssh/ssh-agent.service',
        notify => Nest::Lib::Systemd_reload['ssh'],
      }

      ::nest::lib::systemd_reload { 'ssh': }

      exec { 'ssh-agent-enable-systemd-user-service':
        command => '/bin/systemctl --user --global enable ssh-agent.service',
        creates => '/etc/systemd/user/default.target.wants/ssh-agent.service',
        require => File['/etc/systemd/user/ssh-agent.service'],
      }

      if $::nest::public_ssh {
        firewall { '100 ssh':
          proto  => tcp,
          dport  => 22,
          state  => 'NEW',
          action => accept,
        }
      }
    }

    'windows': {
      package { 'openssh':
        ensure => installed,
      }
    }
  }
}
