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

  # A hack to include my manually-created ext4 volume for MSSQL in /etc/fstab
  Augeas <| title == 'fstab' |> {
    changes +> [
      "set 99/spec /dev/zvol/${hostname}/srv/bitwarden/mssql",
      'set 99/file /srv/bitwarden/bwdata/mssql',
      'set 99/vfstype ext4',
      'set 99/opt[1] defaults',
      'set 99/opt[2] discard',
      'set 99/dump 0',
      'set 99/passno 0',
    ]
  }

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
