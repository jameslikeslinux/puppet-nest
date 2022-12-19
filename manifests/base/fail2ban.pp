class nest::base::fail2ban {
  if $nest::public_ssh {
    $sshd_jail_conf = @(SSHD_JAIL)
      [sshd]
      enabled = true
      backend = systemd
      | SSHD_JAIL

    package { 'net-analyzer/fail2ban':
      ensure => installed,
    }
    ->
    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      '/etc/fail2ban/jail.d':
        ensure => directory,
      ;

      '/etc/fail2ban/jail.d/sshd.conf':
        content => $sshd_jail_conf,
      ;
    }
    ~>
    service { 'fail2ban':
      enable => true,
    }
  } else {
    service { 'fail2ban':
      ensure => stopped,
      enable => false,
    }
    ->
    file { '/etc/fail2ban/jail.d':
      ensure => absent,
      force  => true,
    }
    ->
    package { 'net-analyzer/fail2ban':
      ensure  => absent,
    }
  }
}
