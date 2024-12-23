# @summary Build updated Gentoo Stage 3 images containing Puppet
#
# Use bin/build script to run this plan!
#
# @param container Build container name
# @param tag Build for this CPU architecture
# @param build Build the image
# @param deploy Deploy the image
# @param emerge_default_opts Override default emerge options (e.g. --jobs=4)
# @param gentoo_stage3_tag Use this Gentoo Stage 3 image as the base
# @param init Initialize the build container
# @param makeopts Override make flags (e.g. -j4)
# @param registry Container registry to push to
# @param registry_username Username for registry
# @param registry_password Password for registry
# @param stage0_tag Build using this Stage 0 image
plan nest::build::stage0 (
  String           $container,
  String           $tag,
  Boolean          $build               = true,
  Boolean          $deploy              = false,
  Optional[String] $emerge_default_opts = undef,
  String           $gentoo_stage3_tag   = '',
  Boolean          $init                = true,
  Optional[String] $makeopts            = undef,
  String           $registry            = lookup('nest::build::registry', default_value => 'localhost'),
  Optional[String] $registry_username   = lookup('nest::build::registry_username', default_value => undef),
  Optional[String] $registry_password   = lookup('nest::build::registry_password', default_value => undef),
  String           $stage0_tag          = $tag,
) {
  $debug_volume = "${container}-debug"
  $repos_volume = "${container}-repos" # cached between builds

  if $deploy {
    if $registry_username {
      $registry_password_env = system::env('NEST_REGISTRY_PASSWORD')
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
    if empty($gentoo_stage3_tag) {
      $from_image = "nest/stage0:${stage0_tag}"
    } else {
      $from_image = "nest/gentoo/stage3:${gentoo_stage3_tag}"
    }

    run_command("podman rm -f ${container}", 'localhost', 'Stop and remove existing build container')
    run_command("podman volume rm -f ${debug_volume}", 'localhost', 'Remove existing debug volume')

    # Note: initial LANG applies to all downstream containers
    $podman_create_cmd = @("RUN"/L)
      podman create \
      --env=LANG \
      --name=${container} \
      --pull=always \
      --stop-signal=SIGKILL \
      --volume=/nest:/nest \
      --volume=${debug_volume}:/usr/lib/debug \
      --volume=${repos_volume}:/var/db/repos \
      ${from_image} \
      sleep infinity
      | RUN

    run_command($podman_create_cmd, 'localhost', 'Create build container')
  }

  if $build {
    run_command("podman start ${container}", 'localhost', 'Start build container')

    $target = get_target("podman://${container}")

    if empty($gentoo_stage3_tag) {
      run_command('eix-sync -aq', $target, 'Sync Portage repos')
    } else {
      run_command('sed -i "s@^sync-uri =.*@sync-uri = rsync://rsync.us.gentoo.org/gentoo-portage/@" /usr/share/portage/config/repos.conf', $target, 'Use Gentoo US rsync mirror')
      run_command('emerge --sync', $target, 'Sync Portage tree')
      run_command('emerge --verbose app-admin/puppet app-portage/eix dev-ruby/sys-filesystem', $target, 'Install Puppet', _env_vars => {
        # Settings from Nest overlay
        'ACCEPT_KEYWORDS'     => '*', # latest stable version
        'DISTDIR'             => '/nest/portage/distfiles',
        'EMERGE_DEFAULT_OPTS' => "${emerge_default_opts} --usepkg",
        'FEATURES'            => '-ipc-sandbox -pid-sandbox -network-sandbox -usersandbox',
        'MAKEOPTS'            => $makeopts,
        'PKGDIR'              => "/nest/portage/packages/${tag}",
      })
      run_command('eix-update', $target, 'Update package database')
    }

    apply_prep($target)

    add_facts($target, {
      'build'               => 'init',
      'emerge_default_opts' => $emerge_default_opts,
      'makeopts'            => $makeopts,
      'profile'             => {},
    })

    apply($target, '_description' => 'Configure Portage') {
      include nest
    }.nest::print_report

    run_command("eselect profile set nest:${tag}/server", $target, 'Set profile')
    run_command('emerge --info', $target, 'Show Portage configuration')
    run_command('emerge --emptytree --verbose @world', $target, 'Rebuild all packages')
    run_command('emerge --depclean', $target, 'Remove unused packages')

    run_command("podman stop ${container}", 'localhost', 'Stop build container')
  }

  if $deploy {
    $image = "${registry}/nest/stage0:${tag}"
    run_command("podman commit --change CMD=/bin/bash --squash ${container} ${image}", 'localhost', 'Commit build container')

    $debug_container = "${container}-debug"
    $debug_image = "${registry}/nest/stage0/debug:${tag}"
    run_command("podman run --name=${debug_container} --volume=${debug_volume}:/usr/lib/.debug:ro ${image} cp -a /usr/lib/.debug/. /usr/lib/debug", 'localhost', 'Copy debug symbols')
    run_command("podman commit --change CMD=/bin/bash ${debug_container} ${debug_image}", 'localhost', 'Commit debug container')
    run_command("podman rm ${debug_container}", 'localhost', 'Remove debug container')

    unless $registry == 'localhost' {
      run_command("podman push ${image}", 'localhost', "Push ${image}")
      run_command("podman push ${debug_image}", 'localhost', "Push ${debug_image}")
    }
  }
}
