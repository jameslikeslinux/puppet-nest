class nest::bitwarden {
  include '::nest'
  include '::nest::docker'

  package { 'app-emulation/docker-compose':
    ensure  => installed,
    require => Class['::nest::docker'],
  }

  nest::srv { 'bitwarden': }

  file { '/srv/bitwarden':
    ensure  => directory,
    mode    => '0750',
    owner   => 'bitwarden',
    group   => 'bitwarden',
    require => Nest::Srv['bitwarden'],
  }

  file { '/srv/bitwarden/bitwarden.sh':
    mode     => '0555',
    owner    => 'bitwarden',
    group    => 'bitwarden',
    source   => 'https://raw.githubusercontent.com/bitwarden/core/master/scripts/bitwarden.sh',
    checksum => 'mtime',
  }
}
