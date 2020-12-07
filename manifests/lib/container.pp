define nest::lib::container (
  String $image,
  Enum['running', 'enabled', 'present', 'disabled', 'stopped', 'absent'] $ensure = running,
  Optional[String] $cpuset_cpus = $::nest::availcpus_expanded.join(','),
  Optional[String] $dns         = undef,
  Array[String]    $env         = [],
  Optional[String] $network     = undef,
  Array[String]    $publish     = [],
  Array[String]    $tmpfs       = [],
  Array[String]    $volumes     = [],
) {
  # Required for /usr/bin/podman
  include 'nest'

  if $ensure == absent {
    service { "container-${name}":
      ensure => stopped,
      enable => false,
    }
    ->
    file { "/etc/systemd/system/container-${name}.service":
      ensure => absent,
    }
    ~>
    nest::lib::systemd_reload { "container-${name}": }
    ~>
    exec { "remove-container-${name}":
      command     => "/usr/bin/podman rm ${name.shellquote}",
      refreshonly => true,
    }
  } else {
    case $ensure {
      running: {
        $service_ensure = running
        $service_enable = true
      }

      enabled: {
        $service_ensure = undef
        $service_enable = true
      }

      present: {
        $service_ensure = undef
        $service_enable = undef
      }

      disabled: {
        $service_ensure = undef
        $service_enable = false
      }

      stopped: {
        $service_ensure = stopped
        $service_enable = false
      }

      default: {
        fail("Unhandled value for ensure: '${ensure}'")
      }
    }

    $cpuset_cpus_args = $cpuset_cpus ? {
      undef   => [],
      default => ["--cpuset-cpus=${cpuset_cpus}"],
    }

    $dns_args = $dns ? {
      undef   => [],
      default => ["--dns=${dns}"],
    }

    $env_args = $env.map |$e| {
      "--env=${e}"
    }

    $network_args = $network ? {
      undef   => [],
      default => ["--network=${network}"],
    }

    $publish_args = $publish.map |$e| {
      "--publish=${e}"
    }

    $tmpfs_args = $tmpfs.map |$t| {
      "--tmpfs=${t}"
    }

    $volumes_args = $volumes.map |$volume| {
      "--volume=${volume}"
    }

    $podman_create_cmd = [
      '/usr/bin/podman', 'create',
      '--replace',
      $cpuset_cpus_args,
      $dns_args,
      $env_args,
      $network_args,
      $publish_args,
      $tmpfs_args,
      $volumes_args,
      "--label=nest.podman-version=${facts['podman_version']}",
      "--name=${name}",
      $image,
    ].flatten

    $podman_create_str = "[${podman_create_cmd.join(' ')}]"
    $podman_inspect_create_command = [
      '/usr/bin/podman', 'inspect',
      '--format={{.Config.CreateCommand}}',
      $name,
    ]

    exec { "stop-container-${name}":
      command => "/bin/systemctl stop container-${name}",
      returns => [0, 5],
      unless  => "/usr/bin/test ${podman_create_str.shellquote} = \"`${podman_inspect_create_command.shellquote}`\"",
      require => Class['nest::base::containers'],
    }
    ~>
    exec { "create-container-${name}":
      command     => shellquote($podman_create_cmd),
      refreshonly => true,
    }
    ~>
    exec { "generate-services-container-${name}":
      command     => "/usr/bin/podman generate systemd --files --name ${name.shellquote}",
      cwd         => '/etc/systemd/system',
      refreshonly => true,
    }
    ~>
    nest::lib::systemd_reload { "container-${name}": }
    ->
    service { "container-${name}":
      ensure => $service_ensure,
      enable => $service_enable,
    }
  }
}
