# @summary Build config image
#
# Use bin/build script to run this plan!
#
# @param container Build container name
# @param cpu Build for this CPU architecture
# @param build Build the image
# @param branch Git branch to deploy
# @param deploy Deploy the image
# @param git_private_key_var Environment variable for Git private key
# @param git_repository Config git repository
# @param init Initialize the build container
# @param qemu_user_targets CPU architectures to emulate
# @param registry Container registry to push to
# @param registry_username Username for registry
# @param registry_password Password for registry
# @param registry_password_var Environment variable for registry password
plan nest::build::config (
  String            $container,
  String            $cpu,
  Boolean           $build                 = true,
  Optional[String]  $branch                = undef,
  Boolean           $deploy                = false,
  String            $git_private_key_var   = 'NEST_GIT_PRIVATE_KEY',
  String            $git_repository        = lookup('nest::build::git_repository'),
  Boolean           $init                  = true,
  Array[String]     $qemu_user_targets     = lookup('nest::build::qemu_user_targets', default_value => []),
  String            $registry              = lookup('nest::build::registry', default_value => 'localhost'),
  Optional[String]  $registry_username     = lookup('nest::build::registry_username', default_value => undef),
  Optional[String]  $registry_password     = lookup('nest::build::registry_password', default_value => undef),
  String            $registry_password_var = 'NEST_REGISTRY_PASSWORD',
) {
  $ssh_auth_sock = system::env('SSH_AUTH_SOCK')
  $target = Target.new(name => $container, uri => "podman://${container}")

  if $deploy {
    if $registry_username {
      $registry_password_env = system::env($registry_password_var)
      if $registry_password_env {
        $registry_password_real = $registry_password_env
      } elsif $registry_password {
        $registry_password_real = $registry_password
      } else {
        $registry_password_real = prompt('Registry password', 'sensitive' => true).unwrap
      }

      run_command("echo \$registry_password | podman login --username=${registry_username} --password-stdin ${registry}", 'localhost', 'Login to registry', _env_vars => {
        'registry_password' => $registry_password_real,
      })
    }
  }

  if $init {
    run_command("podman rm -f ${container}", 'localhost', 'Stop and remove existing build container')

    if !empty($ssh_auth_sock) and run_command("test -S ${ssh_auth_sock}", 'localhost', 'Check SSH_AUTH_SOCK', '_catch_errors' => true).ok {
      $ssh_auth_sock_volume = "--volume=${ssh_auth_sock}:${ssh_auth_sock}:ro"
    } else {
      $ssh_auth_sock_volume = ''
    }

    $podman_create_cmd = @("CREATE"/L)
      podman create \
      --name=${container} \
      --pull=always \
      --stop-signal=SIGKILL \
      ${ssh_auth_sock_volume} \
      ${qemu_user_targets.map |$arch| { "--volume=/usr/bin/qemu-${arch}:/usr/bin/qemu-${arch}:ro" }.join(' ')} \
      nest/tools/bolt \
      sleep infinity
      | CREATE

    run_command($podman_create_cmd, 'localhost', 'Create build container')
  }

  if $build {
    run_command("podman start ${container}", 'localhost', 'Start build container')

    if !empty($branch) {
      $branch_args = "--branch ${branch.shellquote}"
    } else {
      $branch_args = ''
    }

    $install_script = @("INSTALL"/$)
      if [[ ! -S \$SSH_AUTH_SOCK ]]; then
        eval $(ssh-agent -s)
        ssh-add =(<<< \$SSH_PRIVATE_KEY)
      fi

      git clone ${branch_args} ${git_repository} /modules/nest
      cd /modules/nest
      bolt module install
      | INSTALL

    run_command("zsh -c ${install_script.shellquote}", $target, 'Install config and modules', '_env_vars' => {
      'SSH_AUTH_SOCK'   => $ssh_auth_sock,
      'SSH_PRIVATE_KEY' => system::env($git_private_key_var),
    })

    run_command("podman stop ${container}", 'localhost', 'Stop build container')
  }

  if $deploy {
    $image = "${registry}/nest/puppet/${branch}:${cpu}"
    run_command("podman commit --change CMD=/bin/zsh --change WORKDIR=/modules/nest ${container} ${image}", 'localhost', 'Commit build container')

    unless $registry == 'localhost' {
      run_command("podman push ${image}", 'localhost', "Push ${image}")
    }
  }
}
