class nest::base::ssh {
  case $facts['os']['family'] {
    'Gentoo': {
      $package_name     = 'net-misc/openssh'
      $package_provider = undef
      $sshdir           = '/etc/ssh'
      $service_name     = 'sshd'
      $service_ensure   = undef

      File {
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
      }

      nest::lib::package_use { 'net-misc/openssh':
        use => 'kerberos',
      }

      file {
        '/etc/systemd/system/sshd.service.d':
          ensure => directory;
        '/etc/systemd/system/sshd.service.d/10-disable-keygen.conf':
          content => "[Service]\nExecStartPre=\n",
        ;
      }
      ~>
      nest::lib::systemd_reload { 'ssh': }
      ~>
      Service[$service_name]

      file { '/etc/systemd/user/ssh-agent.service':
        source => 'puppet:///modules/nest/ssh/ssh-agent.service',
      }
      ->
      exec { 'ssh-agent-enable-systemd-user-service':
        command => '/bin/systemctl --user --global enable ssh-agent.service',
        creates => '/etc/systemd/user/default.target.wants/ssh-agent.service',
      }

      if $nest::public_ssh {
        nest::lib::external_service { 'ssh': }
      }
    }

    'windows': {
      $package_name     = 'openssh'
      $package_provider = 'cygwin'
      $sshdir           = 'C:/tools/cygwin/etc'
      $service_name     = 'cygsshd'
      $service_ensure   = undef

      File {
        owner => 'Administrators',
        group => 'None',
        mode  => '0644',
      }

      exec { 'ssh-host-config':
        command => shellquote(
          'C:/tools/cygwin/bin/bash.exe', '-c',
          'source /etc/profile && /usr/bin/ssh-host-config --yes'
        ),
        creates => 'C:/tools/cygwin/etc/sshd_config',
        require => Package[$package_name],
      }
      ->
      file { 'C:/tools/cygwin/etc/sshd_config':
        # default mode
      }
      ->
      File_line <| path == "${sshdir}/sshd_config" |>

      file { 'C:/tools/cygwin/etc/ssh_known_hosts':
        # default mode
      }
      ->
      Sshkey <||>

      windows_firewall::exception { 'nest-ssh':
        ensure       => present,
        display_name => 'Nest SSH',
        description  => 'Allow SSH from Nest VPN',
        protocol     => 'TCP',
        local_port   => 22,
        remote_ip    => '172.22.0.0/24',
        action       => allow,
      }
    }
  }

  package { $package_name:
    ensure   => installed,
    provider => $package_provider,
  }
  ->
  file_line {
    default:
      path => "${sshdir}/sshd_config",
    ;

    'sshd_config-ChallengeResponseAuthentication':
      line  => 'ChallengeResponseAuthentication no',
      match => '^#?ChallengeResponseAuthentication ',
    ;

    'sshd_config-X11Forwarding':
      line  => 'X11Forwarding yes',
      match => '^#?X11Forwarding ',
    ;

    'sshd_config-X11UseLocalhost':
      after => '^#?X11Forwarding ',
      line  => 'X11UseLocalhost no',
      match => '^#?X11UseLocalhost ',
    ;
  }
  ~>
  service { $service_name:
    ensure => $service_ensure,
    enable => true,
  }

  file { "${sshdir}/ssh_host_ed25519_key":
    mode      => '0600',
    content   => $nest::ssh_private_keys['host'],
    show_diff => false,
    notify    => Service[$service_name],
  }

  # Collect SSH keys exported by other hosts below
  if $facts['build'] in [undef, 'bolt', 'stage3'] {
    Sshkey <<||>>

    $nest::ssh_host_keys.each |$host, $line| {
      $names  = $host.split(/,/)
      $values = $line.split(/\s+/)
      $type   = $values[0]
      $key    = $values[1]

      sshkey { "${names[0]}@${type}":
        key          => $key,
        host_aliases => $names[1, -1],
      }
    }

    resources { 'sshkey':
      purge => true,
    }
  }

  #
  # XXX Cleanup
  #
  file { [
    "${sshdir}/ssh_host_dsa_key",
    "${sshdir}/ssh_host_dsa_key.pub",
    "${sshdir}/ssh_host_ecdsa_key",
    "${sshdir}/ssh_host_ecdsa_key.pub",
    "${sshdir}/ssh_host_ed25519_key.pub",
    "${sshdir}/ssh_host_rsa_key",
    "${sshdir}/ssh_host_rsa_key.pub",
  ]:
    ensure => absent,
    notify => Service[$service_name],
  }

  file_line { 'sshd_config-PubkeyAcceptedKeyTypes':
    ensure            => absent,
    path              => "${sshdir}/sshd_config",
    match             => '^#?PubkeyAcceptedKeyTypes\s*',
    match_for_absence => true,
    notify            => Service[$service_name],
  }
}
