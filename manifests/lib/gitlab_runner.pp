define nest::lib::gitlab_runner (
  String              $registration_token,
  String              $default_image    = "registry.gitlab.james.tl/nest/stage1:${facts['profile']['platform']}-server",
  Optional[String]    $dns              = undef,
  Array[String]       $devices          = [],
  Nest::ServiceEnsure $ensure           = running,
  String              $host             = $name,
  Array[String]       $security_options = [],
  Array[String]       $volumes          = [],
  Array[String]       $tag_list         = [],
  Boolean             $zfs              = false,
) {
  if $ensure == absent {
    nest::lib::container { "gitlab-runner-${name}":
      ensure => absent,
      image  => 'gitlab/gitlab-runner',
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

    $zfs_args = $zfs ? {
      true    => [
        '--docker-cap-add', 'SYS_ADMIN',
        '--docker-devices', '/dev/zfs',
        '--env', 'STORAGE_DRIVER=zfs',
      ],
      default => [],
    }

    # See: https://docs.gitlab.com/runner/register/index.html#one-line-registration-command
    $register_command = [
      '/usr/bin/podman', 'run', '--rm',
      '-v', "/srv/gitlab-runner/${name}:/etc/gitlab-runner",
      'gitlab/gitlab-runner', 'register',
      '--non-interactive',
      '--output-limit', '262144',
      '--executor', 'docker',
      '--docker-image', $default_image,
      '--env', "CI_HOST_EMERGE_DEFAULT_OPTS=${::nest::base::portage::emerge_default_opts}",
      '--env', "CI_HOST_MAKEOPTS=${::nest::base::portage::makeopts}",
      '--env', "CI_HOST_CPU=${facts['profile']['cpu']}",
      $dns_args,
      $device_args,
      $security_opt_args,
      $volume_args,
      $zfs_args,
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
      ensure  => $ensure,
      image   => 'gitlab/gitlab-runner',
      dns     => $dns,
      volumes => [
        '/run/podman/podman.sock:/var/run/docker.sock',
        "/srv/gitlab-runner/${name}:/etc/gitlab-runner",
      ],
      require => Exec["gitlab-runner-${name}-register"],
    }
  }
}
