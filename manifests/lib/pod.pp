define nest::lib::pod (
  Enum['running', 'enabled', 'present', 'disabled', 'stopped', 'absent'] $ensure = running,
  Optional[String] $dns     = undef,
  Array[String]    $publish = [],
) {
  # Required for /usr/bin/podman
  include 'nest'

  if $ensure == absent {
    service { "pod-${name}":
      ensure => stopped,
      enable => false,
    }
    ->
    exec { "remove-pod-${name}":
      command => "/usr/bin/podman pod rm ${name.shellquote}",
      onlyif  => "/usr/bin/podman pod exists ${name.shellquote}",
    }

    file { "/etc/systemd/system/pod-${name}.service":
      ensure => absent,
    }
    ~>
    nest::lib::systemd_reload { "pod-${name}":
      require => Service["pod-${name}"],
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

    $dns_args = $dns ? {
      undef   => [],
      default => ["--dns=${dns}"],
    }

    $publish_args = $publish.map |$e| {
      "--publish=${e}"
    }

    $podman_create_cmd = [
      '/usr/bin/podman', 'pod', 'create',
      '--replace',
      $dns_args,
      $publish_args,
      "--label=nest.podman.version=${facts['podman_version']}",
      "--name=${name}",
    ].flatten

    $podman_create_str = "[${podman_create_cmd.join(' ')}]"
    $podman_inspect_create_command = [
      '/usr/bin/podman', 'pod', 'inspect',
      '--format={{.CreateCommand}}',
      $name,
    ]

    exec { "stop-pod-${name}":
      command => "/bin/systemctl stop pod-${name}",
      returns => [0, 5],
      unless  => "/usr/bin/test ${podman_create_str.shellquote} = \"`${podman_inspect_create_command.shellquote}`\"",
      require => Class['nest::base::containers'],
    }
    ~>
    exec { "create-pod-${name}":
      command     => shellquote($podman_create_cmd),
      refreshonly => true,
    }
    ~>
    exec { "generate-services-pod-${name}":
      command     => "/usr/bin/podman generate systemd --files --name ${name.shellquote}",
      cwd         => '/etc/systemd/system',
      refreshonly => true,
    }
    ~>
    nest::lib::systemd_reload { "pod-${name}": }
    ->
    service { "pod-${name}":
      ensure => $service_ensure,
      enable => $service_enable,
    }
  }
}
