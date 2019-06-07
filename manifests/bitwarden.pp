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

  if $facts['bitwarden_installed'] {
    $env.each |$key, $value| {
      $key_escaped = regexpescape($key)

      file_line { "bitwarden-env-${key}":
        path   => '/srv/bitwarden/bwdata/env/global.override.env',
        line   => "${key}=${value}",
        match  => "^${key_escaped}=",
        notify => Exec['restart-bitwarden'],
      }
    }

    exec { 'restart-bitwarden':
      command     => '/srv/bitwarden/bitwarden.sh restart',
      user        => 'bitwarden',
      refreshonly => true,
    }
  }
}
