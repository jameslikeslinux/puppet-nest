define nest::lib::gitlab_runner (
  String $registration_token,
  Enum['running', 'enabled', 'present', 'disabled', 'stopped', 'absent'] $ensure = running,
  String $host                    = $name,
  String $default_image           = 'registry.gitlab.james.tl/nest/stage1:haswell-server',
  Optional[String] $cpuset_cpus   = $::nest::availcpus_expanded.join(','),
  Optional[String] $dns           = undef,
  Array[String] $devices          = [],
  Array[String] $security_options = [],
  Array[String] $volumes          = [],
  Array[String] $tag_list         = [],
) {
  if $ensure == absent {
    nest::lib::container { "gitlab-runner-${name}":
      image  => 'gitlab/gitlab-runner',
      ensure => absent,
    }
    ->
    file { "/srv/gitlab-runner/${name}":
      ensure  => absent,
      recurse => true,
      force   => true,
    }
  } else {
    # Required for /usr/bin/podman
    include 'nest'

    # Required for /srv/gitlab-runner
    include 'nest::service::gitlab_runner'

    file { "/srv/gitlab-runner/${name}":
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    $cpuset_cpus_args = $cpuset_cpus ? {
      undef   => [],
      default => ['--docker-cpuset-cpus', $cpuset_cpus],
    }

    $dns_args = $dns ? {
      undef   => [],
      default => ['--docker-dns', $dns],
    }

    $device_args = $devices.map |$device| {
      ['--docker-devices', $device]
    }

    $security_opt_args = $security_options.map |$option| {
      ['--docker-security-opt', $option]
    }

    $volume_args = $volumes.map |$volume| {
      ['--docker-volumes', $volume]
    }

    # See: https://docs.gitlab.com/runner/register/index.html#one-line-registration-command
    $register_command = [
      '/usr/bin/podman', 'run', '--rm',
      '-v', "/srv/gitlab-runner/${name}:/etc/gitlab-runner",
      'gitlab/gitlab-runner', 'register',
      '--non-interactive',
      '--executor', 'docker',
      '--docker-image', $default_image,
      '--env', "CI_HOST_MAKEOPTS=${::nest::base::portage::makeopts}",
      '--env', "CI_HOST_PLATFORM=${::platform}",
      $cpuset_cpus_args,
      $dns_args,
      $device_args,
      $security_opt_args,
      $volume_args,
      '--url', "https://${host}/",
      '--registration-token', $registration_token,
      '--description', $facts['hostname'],
      '--tag-list', $tag_list.join(','),
    ].flatten

    exec { "gitlab-runner-${name}-register":
      command => shellquote($register_command),
      creates => "/srv/gitlab-runner/${name}/config.toml",
      require => File["/srv/gitlab-runner/${name}"],
    }

    nest::lib::container { "gitlab-runner-${name}":
      ensure      => $ensure,
      image       => 'gitlab/gitlab-runner',
      cpuset_cpus => $cpuset_cpus,
      dns         => $dns,
      volumes     => [
        '/run/podman/podman.sock:/var/run/docker.sock',
        "/srv/gitlab-runner/${name}:/etc/gitlab-runner",
      ],
      require     => Exec["gitlab-runner-${name}-register"],
    }
  }
}
