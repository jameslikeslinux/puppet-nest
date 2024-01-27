define nest::lib::gitlab_runner (
  String            $host,
  String            $registration_token,
  String            $default_image    = "registry.gitlab.james.tl/nest/stage1:${facts['profile']['platform']}-server",
  Optional[String]  $dns              = undef,
  Array[String]     $devices          = [],
  Nest::Ensure      $ensure           = present,
  Optional[Integer] $limit            = undef,
  Array[String]     $cap_add          = [],
  Array[String]     $security_options = [],
  Array[String]     $volumes          = [],
  Boolean           $privileged       = false,
  Boolean           $zfs              = false,
) {
  # Required for /srv/gitlab-runner and container
  include 'nest::service::gitlab_runner'

  if $limit {
    $limit_args = ['--limit', String($limit)]
  } else {
    $limit_args = []
  }

  $dns_args = $dns ? {
    undef   => [],
    default => ['--docker-dns', $dns],
  }

  $device_args = $devices.map |$device| {
    ['--docker-devices', $device]
  }

  $cap_add_args = $cap_add.map |$c| {
    ['--docker-cap-add', $c]
  }

  $security_opt_args = $security_options.map |$option| {
    ['--docker-security-opt', $option]
  }

  $volume_args = $volumes.map |$volume| {
    ['--docker-volumes', $volume]
  }

  if $privileged {
    $privileged_args = ['--docker-privileged']
  } else {
    $privileged_args = []
  }

  $zfs_args = $zfs ? {
    true    => [
      '--docker-devices', '/dev/zfs',
      '--docker-privileged',
      '--docker-volumes', '/var/lib/containers/storage:/var/lib/containers/storage',
      '--env', 'STORAGE_DRIVER=zfs',
    ],
    default => [],
  }

  # See: https://docs.gitlab.com/runner/register/index.html#one-line-registration-command
  $register_command = [
    'gitlab-runner', 'register',
    '--description', $trusted['certname'],
    '--non-interactive',
    $limit_args,
    '--output-limit', '524288',
    '--executor', 'docker',
    '--docker-image', $default_image,
    '--env', "CI_HOST_EMERGE_DEFAULT_OPTS=${nest::base::portage::emerge_default_opts}",
    '--env', "CI_HOST_MAKEOPTS=${nest::base::portage::makeopts}",
    '--env', "CI_HOST_CPU=${facts['profile']['cpu']}",
    $dns_args,
    $device_args,
    $cap_add_args,
    $security_opt_args,
    $volume_args,
    $privileged_args,
    $zfs_args,
    '--url', "https://${host}/",
    '--token', $registration_token,
  ].flatten.shellquote

  $unregister_command = @(CMD/L)
    /usr/local/bin/gitlab-runner unregister --all-runners && \
    /bin/rm -f /srv/gitlab-runner/config.toml
    | CMD

  unless $facts['is_container'] {
    if $ensure == present {
      unless defined(Exec['gitlab-runner-unregister-all']) {
        exec { 'gitlab-runner-unregister-all':
          command     => $unregister_command,
          refreshonly => true,
        }
      }

      file { "/srv/gitlab-runner/.register-${name}.sh":
        mode    => '0600',
        owner   => 'root',
        group   => 'root',
        content => "${register_command}\n",
        notify  => Exec['gitlab-runner-unregister-all'],
      }

      exec { "gitlab-runner-register-${name}":
        command     => "/bin/sh /srv/gitlab-runner/.register-${name}.sh",
        refreshonly => true,
        subscribe   => Exec['gitlab-runner-unregister-all'],
      }
    } else {
      exec { 'gitlab-runner-unregister-all':
        command => "${unregister_command}; rm -f /srv/gitlab-runner/.register-${name}.sh",
      }
    }
  }
}
