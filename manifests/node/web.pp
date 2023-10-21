class nest::node::web {
  include 'nest::service::bitwarden'
  include 'nest::service::mysql'

  unless $facts['is_container'] {
    mysql::db { 'bitwarden':
      user     => 'bitwarden',
      password => $nest::service::bitwarden::database_password,
      host     => '%',
      before   => Class['nest::service::bitwarden'],
    }
  }

  # Allow older PHP SSH2 host key algorithm
  file { '/etc/ssh/sshd_config.d/allow-php-hostkeyalgorithm.conf':
    content => "HostKeyAlgorithms +ssh-rsa\n",
    require => Package['net-misc/openssh'],
    notify  => Service['sshd'],
  }
}
