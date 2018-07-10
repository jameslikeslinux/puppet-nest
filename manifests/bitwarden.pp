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

  # Deploy workaround for running mssql on ZFS
  # See: https://github.com/t-oster/mssql-docker-zfs
  file { '/srv/bitwarden/nodirect_open.so':
    mode   => '0755',
    owner  => 'bitwarden',
    group  => 'bitwarden',
    source => 'puppet:///modules/nest/bitwarden/nodirect_open.so',
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

    file_line { 'bitwarden-docker-compose-nodirect_open-volume':
      path   => '/srv/bitwarden/bwdata/docker/docker-compose.yml',
      line   => '      - ../../nodirect_open.so:/nodirect_open.so',
      after  => '      - ../mssql/data:/var/opt/mssql/data',
      notify => Service['bitwarden'],
    }

    file_line { 'bitwarden-mssql-env-LD_PRELOAD':
      path   => '/srv/bitwarden/bwdata/env/mssql.override.env',
      line   => 'LD_PRELOAD=/nodirect_open.so',
      notify => Service['bitwarden'],
    }

    service { 'bitwarden':
      enable  => true,
      require => Exec['bitwarden-systemd-daemon-reload'],
    }
  }
}
