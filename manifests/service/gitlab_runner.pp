define nest::service::gitlab_runner (
  String $registration_token,
  String $host            = $name,
  String $default_image   = 'ubuntu:latest',
  String $description     = $facts['fqdn'],
  Array[String] $volumes  = [],
  Array[String] $tag_list = [],
) {
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

  $volume_args = $volumes.map |$volume| {
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
  ] + $volume_args

  exec { "gitlab-runner-${name}-register":
    command => shellquote($register_command),
    creates => "/srv/gitlab-runner/${name}/config.toml",
    require => File["/srv/gitlab-runner/${name}"],
  }

  nest::lib::podman_container { "gitlab-runner-${name}":
    image   => 'gitlab/gitlab-runner',
    volumes => [
      '/run/podman/podman.sock:/var/run/docker.sock',
      "/srv/gitlab-runner/${name}:/etc/gitlab-runner",
    ],
    require => Exec["gitlab-runner-${name}-register"],
  }
}
