class nest::profile::base::ssh {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::portage::package_use { 'net-misc/openssh':
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
        notify => Nest::Systemd_reload['puppet'],
      }

      ::nest::systemd_reload { 'puppet': }

      exec { 'ssh-agent-enable-systemd-user-service':
        command => '/bin/systemctl --user --global enable ssh-agent.service',
        creates => '/etc/systemd/user/default.target.wants/ssh-agent.service',
        require => File['/etc/systemd/user/ssh-agent.service'],
      }

      # XXX: Remove this after 20170719
      file_line { 'pam_env.conf-SSH_AUTH_SOCK':
        ensure => absent,
        path   => '/etc/security/pam_env.conf',
        line   => 'SSH_AUTH_SOCK	DEFAULT="${XDG_RUNTIME_DIR}/ssh-agent.socket"',
      }
    }

    'windows': {
      package { 'openssh':
        ensure => installed,
      }
    }
  }
}
