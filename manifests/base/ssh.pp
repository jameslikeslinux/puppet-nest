class nest::base::ssh {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::lib::package_use { 'net-misc/openssh':
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
        firewall {
          default:
            proto  => tcp,
            dport  => 22,
            state  => 'NEW',
            action => accept,
          ;

          '100 ssh (v4)':
            provider => iptables,
          ;

          '100 ssh (v6)':
            provider => ip6tables,
          ;
        }
      }
    }

    'windows': {
      package { 'openssh':
        ensure   => installed,
        provider => 'cygwin',
      }
      ->
      exec { 'ssh-host-config':
        command => shellquote(
          'C:/tools/cygwin/bin/bash.exe', '-c',
          'source /etc/profile && /usr/bin/ssh-host-config --yes'
        ),
        creates => 'C:/tools/cygwin/etc/sshd_config',
      }
      ->
      file_line { 'sshd_config-PubkeyAcceptedKeyTypes':
        path  => 'C:/tools/cygwin/etc/sshd_config',
        line  => 'PubkeyAcceptedKeyTypes +ssh-rsa',
        match => '^#?PubkeyAcceptedKeyTypes\s*',
        after => '^#?PubkeyAuthentication\s*',
      }
      ~>
      service { 'cygsshd':
        ensure => running,
        enable => true,
      }

      file { 'C:/tools/cygwin/etc/ssh_known_hosts':
        mode  => '0644',
        owner => 'Administrators',
        group => 'None',
      }
    }
  }

  # Export SSH keys for collecting on other hosts
  ['ssh', 'cygwin_ssh'].each |$ssh_fact| {
    if $facts[$ssh_fact] {
      $facts[$ssh_fact].each |$key, $value| {
        @@sshkey { "${trusted['certname']}.nest@${value['type']}":
          key => $value['key'],
        }
      }
    }
  }

  # Collect SSH keys exported by other hosts below
  if $facts['build'] in [undef, 'stage3'] {
    Sshkey <<||>>

    resources { 'sshkey':
      purge => true,
    }
  }
}
