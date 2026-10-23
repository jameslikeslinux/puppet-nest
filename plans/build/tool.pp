# @summary Build a standard tool image
#
# Use bin/build script to run this plan!
#
# @param container Build container name
# @param cpu Build for this CPU architecture
# @param tool Build this tool
# @param tag Image tag to publish/use on refresh; defaults to cpu
# @param build Build the image
# @param candidate Candidate token; requires fresh execution and returns only the verified candidate digest
# @param deploy Deploy the image
# @param emerge_default_opts Override default emerge options (e.g. --jobs=4)
# @param extra_volumes Additional volumes to mount into the build container
# @param from_image Exact fresh/refresh base digest; requires init=true
# @param id Build ID
# @param image_changes Additional image instruction (e.g. ENV=NAME=val,WORKDIR=/path)
# @param init Initialize the build container
# @param makeopts Override make flags (e.g. -j4)
# @param qemu_user_targets CPU architectures to emulate
# @param refresh Build from previous tool image
# @param registry Container registry to push to
# @param registry_username Username for registry
# @param registry_password Password for registry
# @param registry_password_var Environment variable for registry password
# @param repo_revisions Complete gentoo/nest/haskell commit pins; isolated repositories, no sync
# @param base_variant Stage1 variant used for a fresh tool image
# @param base_cpu Stage1 CPU tag for a fresh image; defaults to cpu
plan nest::build::tool (
  String            $container,
  String            $cpu,
  String            $tool,
  Optional[String]  $tag                   = undef,
  Boolean           $build                 = true,
  Optional[String]  $candidate             = undef,
  Boolean           $deploy                = false,
  Optional[String]  $emerge_default_opts   = undef,
  Array[String]     $extra_volumes         = [],
  Optional[String]  $from_image            = undef,
  Optional[Numeric] $id                    = undef,
  Array[String]     $image_changes         = [],
  Boolean           $init                  = true,
  Optional[String]  $makeopts              = undef,
  Array[String]     $qemu_user_targets     = lookup('nest::build::qemu_user_targets', default_value => []),
  Boolean           $refresh               = false,
  String            $registry              = lookup('nest::build::registry', default_value => 'localhost'),
  Optional[String]  $registry_username     = lookup('nest::build::registry_username', default_value => undef),
  Optional[String]  $registry_password     = lookup('nest::build::registry_password', default_value => undef),
  String            $registry_password_var = 'NEST_REGISTRY_PASSWORD',
  Optional[Hash]    $repo_revisions        = undef,
  String            $base_variant          = 'server',
  Optional[String]  $base_cpu              = undef,
) {
  if $candidate != undef {
    assert_type(Pattern[/\A[a-z0-9][a-z0-9._-]{0,100}\z/], $candidate)
    unless $build and $deploy and $init and $from_image and $registry != 'localhost' and $tag == undef {
      fail('Candidate tool publication requires build, deploy, init, an exact base, no tag override and a remote registry')
    }
  }
  if $from_image != undef {
    assert_type(Pattern[/\A[a-z0-9][a-z0-9._:\/-]*@sha256:[0-9a-f]{64}\z/], $from_image)
    unless $init {
      fail('Pinned tool base requires init=true; an existing container has not consumed this input')
    }
  }
  if $repo_revisions != undef {
    assert_type(Struct[{
      'gentoo'  => Pattern[/\A[0-9a-f]{40}\z/],
      'nest'    => Pattern[/\A[0-9a-f]{40}\z/],
      'haskell' => Pattern[/\A[0-9a-f]{40}\z/],
    }], $repo_revisions)
    unless $build and $init and $from_image {
      fail('Frozen tool repositories require build, init and an exact base')
    }
    # An extra mount must not hide any part of the independently frozen tree.
    # PDK's existing read-only build credential mount cannot hide repositories
    # and is not copied into the committed image. No arbitrary override is safe.
    unless $extra_volumes.empty or ($tool == 'pdk' and $extra_volumes == ['/etc/gemrc:/etc/gemrc:ro']) {
      fail('Frozen tool repositories do not support extra volume overrides')
    }
    $repos_volume_arg = "--volume=${container}-frozen-repos:/var/db/repos:nocopy"
    $repo_args = [$repo_revisions['gentoo'], $repo_revisions['nest'], $repo_revisions['haskell']]
  } else {
    $repos_volume_arg = "--volume=${container}-repos:/var/db/repos"
  }
  if ($emerge_default_opts and $emerge_default_opts =~ /\$/) or ($makeopts and $makeopts =~ /\$/) {
    fail('Build options must be passed already-expanded; literal shell substitutions such as $(nproc) are written to make.conf and break Portage')
  }

  $image_tag = $tag ? {
    undef   => $cpu,
    default => $tag,
  }

  $target = Target.new(name => $container, uri => "podman://${container}")
  $extra_volume_args = $extra_volumes.map |$volume| { "--volume=${volume}" }.join(' ')

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

      run_command("podman login --username=${registry_username} --password-stdin ${registry} <<< \$registry_password", 'localhost', 'Login to registry', _env_vars => {
        'registry_password' => $registry_password_real,
      })
    }
  }

  if $init {
    if $refresh {
      $default_image = "${registry}/nest/tools/${tool}:${image_tag}"
    } else {
      $stage1_cpu = $base_cpu ? {
        undef   => $cpu,
        default => $base_cpu,
      }
      $default_image = "nest/stage1/${base_variant}:${stage1_cpu}"
    }
    $base_image = pick($from_image, $default_image)

    run_command("podman rm -f ${container}", 'localhost', 'Stop and remove existing build container')
    if $repo_revisions != undef {
      run_command("podman volume rm -f ${container}-frozen-repos", 'localhost', 'Remove previous isolated build repositories')
    }

    $podman_create_cmd = @("CREATE"/L)
      podman create \
      --init \
      --name=${container} \
      --pull=always \
      --volume=/nest:/nest \
      ${qemu_user_targets.map |$arch| { "--volume=/usr/bin/qemu-${arch}:/usr/bin/qemu-${arch}:ro" }.join(' ')} \
      ${repos_volume_arg} \
      ${extra_volume_args} \
      ${base_image.shellquote} \
      sleep infinity
      | CREATE

    run_command($podman_create_cmd, 'localhost', 'Create build container')
  }

  if $build {
    run_command("podman start ${container}", 'localhost', 'Start build container')

    if $repo_revisions != undef {
      run_script('nest/build/freeze-repos.py', $target, arguments => ['prepare'] + $repo_args)
    } else {
      run_command('eix-sync -aq', $target, 'Sync Portage repos')
    }

    # Set up the build environment
    $target.apply_prep
    $target.add_facts({
      'build'               => $tool,
      'emerge_default_opts' => $emerge_default_opts,
      'makeopts'            => $makeopts,
    })

    # Apply the configuration
    apply($target, '_description' => 'Configure the tool') { include nest }.nest::print_report
    if $repo_revisions != undef {
      run_script('nest/build/freeze-repos.py', $target, arguments => ['check'] + $repo_args)
    }

    run_command("podman stop ${container}", 'localhost', 'Stop build container')
  }

  if $deploy {
    $commit_changes = (['CMD=/bin/zsh'] + $image_changes).map |$change| { "--change ${change.shellquote}" }.join(' ')
    $output_tag = $candidate ? {
      undef   => $image_tag,
      default => "candidate-${candidate}",
    }
    $image = "${registry}/nest/tools/${tool}:${output_tag}"
    run_command("podman commit ${commit_changes} ${container} ${image}", 'localhost', 'Commit build container')

    if $candidate != undef {
      $image_ref = run_script('nest/build/publish-image.sh', 'localhost', arguments => [$image]).first.value['stdout'].strip
      assert_type(Pattern[/\A[a-z0-9][a-z0-9._:\/-]*@sha256:[0-9a-f]{64}\z/], $image_ref)
      unless $image_ref.split('@')[0] == "${registry}/nest/tools/${tool}" {
        fail('Candidate tool publisher returned a different repository')
      }
      return({ 'image' => $image_ref })
    } elsif $registry != 'localhost' {
      run_command("podman push ${image}", 'localhost', "Push ${image}")
    }
  }
}
