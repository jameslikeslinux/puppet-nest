class nest::bitwarden (
  Hash[String[1], String[1]] $env = {},
) {
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

  file { '/srv/bitwarden/nodirect_open.c':
    mode   => '0644',
    owner  => 'bitwarden',
    group  => 'bitwarden',
    source => 'puppet:///modules/nest/bitwarden/nodirect_open.c',
    notify => Exec['compile-nodirect_open.c'],
  }

  exec { 'compile-nodirect_open.c':
    command     => '/usr/bin/gcc -shared /srv/bitwarden/nodirect_open.c -o /srv/bitwarden/nodirect_open.so',
    user        => 'bitwarden',
    refreshonly => true,
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
    $env.each |$key, $value| {
      $key_escaped = regexpescape($key)

      file_line { "bitwarden-env-${key}":
        path   => '/srv/bitwarden/bwdata/env/global.override.env',
        line   => "${key}=${value}",
        match  => "^${key_escaped}=",
        notify => Service['bitwarden'],
      }
    }

    service { 'bitwarden':
      enable  => true,
      require => Exec['bitwarden-systemd-daemon-reload'],
    }
  }
}
