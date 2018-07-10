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

  vcsrepo { '/srv/bitwarden/core':
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/bitwarden/core.git',
    revision => 'master',
    user     => 'bitwarden',
    require  => File['/srv/bitwarden'],
  }

  file { '/srv/bitwarden/bitwarden.sh':
    ensure  => symlink,
    target  => 'core/scripts/bitwarden.sh',
    owner   => 'bitwarden',
    group   => 'bitwarden',
    require => Vcsrepo['/srv/bitwarden/core'],
  }

  $service_ensure = $facts['bitwarden_installed'] ? {
    true    => present,
    default => absent,
  }

  file { '/etc/systemd/system/bitwarden.service':
    ensure => $service_ensure,
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/bitwarden/bitwarden.service',
    notify => Exec['bitwarden-systemd-daemon-reload'],
  }

  exec { 'bitwarden-systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  if $facts['bitwarden_installed'] {
    service { 'bitwarden':
      enable  => true,
      require => Exec['bitwarden-systemd-daemon-reload'],
    }
  }
}
