class nest::base::containers {
  case $::nest::containers {
    podman: {
      service { 'docker':
        ensure => stopped,
        enable => false,
      }

      package { 'app-emulation/docker':
        ensure  => absent,
        require => Service['docker'],
      }

      zfs { 'containers':
        name       => "${facts['rpool']}/containers",
        mountpoint => '/var/lib/containers',
      }

      package { 'app-emulation/libpod':
        ensure => installed,
      }

      file { '/usr/bin/docker':
        ensure  => link,
        target  => '/usr/bin/podman',
        require => [
          Package['app-emulation/docker'],
          Package['app-emulation/libpod'],
        ],
      }

      file {
        default:
          mode    => '0644',
          owner   => 'root',
          group   => 'root',
          require => Package['app-emulation/libpod'],
          before  => Service['podman.socket'],
        ;

        '/etc/containers/policy.json':
          source => 'puppet:///modules/nest/containers/policy.json',
        ;

        '/etc/containers/registries.conf':
          source => 'puppet:///modules/nest/containers/registries.conf',
        ;
      }

      service { 'podman.socket':
        ensure => running,
        enable => true,
      }

      [File['/usr/bin/docker'], Service['podman.socket']] -> Docker_network <||>
      [File['/usr/bin/docker'], Service['podman.socket']] -> Docker_volume <||>

      Docker::Run <||> {
        depend_services => [],
      }
    }

    docker: {
      zfs { 'docker':
        name       => "${facts['rpool']}/docker",
        mountpoint => '/var/lib/docker',
      }

      class { 'docker':
        acknowledge_unsupported_os => true,
        docker_ce_package_name     => 'app-emulation/docker',
        service_config             => '/etc/conf.d/docker',
        service_config_template    => 'docker/etc/sysconfig/docker.systemd.erb',
        service_overrides_template => 'nest/docker/systemd-overrides.conf.erb',
        service_provider           => 'systemd',
        require                    => Zfs['docker'],
      }

      Class['docker'] -> Docker_network <||>
      Class['docker'] -> Docker_volume <||>

      User <| title == 'james' or title == 'bitwarden' |> {
        groups  +> 'docker',
        require +> Class['docker'],
      }
    }

    default: {
      # Do nothing
    }
  }
}
