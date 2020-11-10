class nest::base::fail2ban {
  if $::nest::public_ssh {
    package { 'net-analyzer/fail2ban':
      ensure => installed,
    }

    $sshd_jail_conf = @(SSHD_JAIL)
      [sshd]
      enabled = true
      backend = systemd
      | SSHD_JAIL

    file { '/etc/fail2ban/jail.d/sshd.local':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $sshd_jail_conf,
      require => Package['net-analyzer/fail2ban'],
      notify  => Service['fail2ban'],
    }

    service { 'fail2ban':
      enable => true,
    }
  } else {
    service { 'fail2ban':
      enable => false,
    }

    file { '/etc/fail2ban/jail.d/sshd.local':
      ensure  => absent,
    }

    package { 'net-analyzer/fail2ban':
      ensure  => absent,
      require => [
        Service['fail2ban'],
        File['/etc/fail2ban/jail.d/sshd.local'],
      ]
    }
  }
}
