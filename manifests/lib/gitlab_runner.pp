define nest::lib::gitlab_runner (
  String            $host,
  String            $registration_token,
  String            $default_image    = "registry.gitlab.james.tl/nest/stage1:${nest::canonical_cpu}-server",
  Optional[String]  $dns              = undef,
  Array[String]     $devices          = [],
  Nest::Ensure      $ensure           = present,
  Optional[Integer] $limit            = undef,
  Array[String]     $cap_add          = [],
  Array[String]     $security_options = [],
  Array[String]     $volumes          = [],
  Boolean           $bolt             = false,
  Boolean           $buildah          = false,
  Boolean           $nest             = false,
  Boolean           $podman           = false,
  Boolean           $portage          = false,
  Boolean           $privileged       = false,
  Boolean           $qemu             = false,
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

  if $bolt {
    $compatible_cpu = $facts['profile']['architecture'] ? {
      'arm64' => 'cortex-a53',
      default => $nest::canonical_cpu,
    }

    $bolt_args = [
      '--docker-volumes', '/etc/eyaml:/etc/eyaml:ro',
      '--docker-volumes', '/etc/puppetlabs/bolt:/etc/puppetlabs/bolt:ro',
      '--env', "CI_HOST_COMPATIBLE_CPU=${compatible_cpu}",
    ]
  } else {
    $bolt_args = []
  }

  if $buildah {
    $buildah_args = [
      '--docker-cap-add', 'SYS_CHROOT',
      '--env', 'STORAGE_DRIVER=vfs',
    ]
  } else {
    $buildah_args = []
  }

  if $nest {
    $nest_args = [
      '--docker-volumes', '/nest:/nest',
      '--docker-volumes', '/falcon:/falcon',
    ]
  } else {
    $nest_args = []
  }

  if $podman {
    $podman_args = [
      '--docker-volumes', '/run/podman/podman.sock:/run/podman/podman.sock:ro',
      '--env', 'CONTAINER_HOST=unix:///run/podman/podman.sock',
    ]
  } else {
    $podman_args = []
  }

  if $portage {
    $portage_args = [
      '--docker-cap-add', 'SYS_PTRACE',
      '--docker-security-opt', 'seccomp=unconfined',
    ]
  } else {
    $portage_args = []
  }

  if $privileged {
    $privileged_args = ['--docker-privileged']
  } else {
    $privileged_args = []
  }

  if $qemu {
    $qemu_args = [
      '--docker-volumes', '/usr/bin/qemu-aarch64:/usr/bin/qemu-aarch64:ro',
      '--docker-volumes', '/usr/bin/qemu-arm:/usr/bin/qemu-arm:ro',
      '--docker-volumes', '/usr/bin/qemu-riscv64:/usr/bin/qemu-riscv64:ro',
      '--docker-volumes', '/usr/bin/qemu-x86_64:/usr/bin/qemu-x86_64:ro',
    ]
  } else {
    $qemu_args = []
  }

  if $zfs {
    $zfs_args = [
      '--docker-devices', '/dev/zfs',
      '--docker-privileged',
    ]
  } else {
    $zfs_args = []
  }

  # See: https://docs.gitlab.com/runner/register/index.html#one-line-registration-command
  $register_command = [
    'gitlab-runner', 'register',
    '--description', $trusted['certname'],
    '--non-interactive',
    $limit_args,
    '--output-limit', '524288',
    '--executor', 'docker',
    '--docker-helper-image', 'alpinelinux/gitlab-runner-helper',
    '--docker-image', $default_image,
    '--env', "CI_HOST_EMERGE_DEFAULT_OPTS=${nest::base::portage::emerge_default_opts}",
    '--env', "CI_HOST_MAKEOPTS=${nest::base::portage::makeopts}",
    '--env', "CI_HOST_CPU=${nest::canonical_cpu}",
    $dns_args,
    $device_args,
    $cap_add_args,
    $security_opt_args,
    $volume_args,
    $bolt_args,
    $buildah_args,
    $nest_args,
    $podman_args,
    $portage_args,
    $privileged_args,
    $qemu_args,
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
