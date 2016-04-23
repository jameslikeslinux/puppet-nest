class nest::profile::base::ssh {
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
}
