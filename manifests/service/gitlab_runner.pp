define nest::service::gitlab_runner (
  String $registration_token,
  String $host                  = $name,
  String $default_image         = 'ubuntu:latest',
  String $description           = $facts['fqdn'],
  Array[String] $docker_volumes = [],
  Array[String] $tag_list       = [],
) {
  include 'nest::service::docker'

  unless defined(Nest::Lib::Srv['gitlab-runner']) {
    nest::lib::srv { 'gitlab-runner': }
  }

  file { "/srv/gitlab-runner/${name}":
    ensure    => directory,
    mode      => '0755',
    owner     => 'root',
    group     => 'root',
    require   => Nest::Lib::Srv['gitlab-runner'],
  }

  $description_real = $description ? {
    undef   => $facts['fqdn'],
    default => "${facts['fqdn']}-${description}",
  }

  $docker_volume_args = $docker_volumes.map |$volume| {
    ['--docker-volumes', $volume]
  }.flatten

  # See: https://docs.gitlab.com/runner/register/index.html#one-line-registration-command
  $register_command = [
    '/usr/bin/docker', 'run', '--rm',
    '-v', "/srv/gitlab-runner/${name}:/etc/gitlab-runner",
    'gitlab/gitlab-runner', 'register',
    '--non-interactive',
    '--executor', 'docker',
    '--docker-image', $default_image,
    '--url', "https://${host}/",
    '--registration-token', $registration_token,
    '--description', $description,
    '--tag-list', $tag_list.join(','),
  ] + $docker_volume_args

  exec { "gitlab-runner-${name}-register":
    command => shellquote($register_command),
    creates => "/srv/gitlab-runner/${name}/config.toml",
    require => File["/srv/gitlab-runner/${name}"],
  }

  docker::run { "gitlab-runner-${name}":
    image            => 'gitlab/gitlab-runner',
    volumes          => [
      '/var/run/docker.sock:/var/run/docker.sock',
      "/srv/gitlab-runner/${name}:/etc/gitlab-runner",
    ],
    service_provider => 'systemd',
    require          => Exec["gitlab-runner-${name}-register"],
  }
}
