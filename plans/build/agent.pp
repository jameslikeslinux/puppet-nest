# @summary Build generic Hermes agent terminal-runtime tool image
#
# Use bin/build script to run this plan!
#
# @param container Build container name
# @param cpu Build for this CPU architecture
# @param tag Image tag to publish; defaults to latest
# @param build Build the image
# @param candidate Frozen candidate token; smoke must pass before publication
# @param deploy Deploy the image
# @param emerge_default_opts Override default emerge options (e.g. --jobs=4)
# @param from_image Exact fresh/refresh base digest; requires init=true
# @param id Build ID
# @param init Initialize the build container
# @param makeopts Override make flags (e.g. -j4)
# @param qemu_user_targets CPU architectures to emulate
# @param refresh Build from previous tool image
# @param registry Container registry to push to
# @param registry_username Username for registry
# @param registry_password Password for registry
# @param registry_password_var Environment variable for registry password
# @param repo_revisions Complete isolated gentoo/nest/haskell commit pins
plan nest::build::agent (
  String            $container,
  String            $cpu                   = 'zen5',
  Optional[String]  $tag                   = undef,
  Boolean           $build                 = true,
  Optional[String]  $candidate             = undef,
  Boolean           $deploy                = false,
  Optional[String]  $emerge_default_opts   = undef,
  Optional[String]  $from_image            = undef,
  Optional[Numeric] $id                    = undef,
  Boolean           $init                  = true,
  Optional[String]  $makeopts              = undef,
  Array[String]     $qemu_user_targets     = lookup('nest::build::qemu_user_targets', default_value => []),
  Boolean           $refresh               = false,
  String            $registry              = lookup('nest::build::registry', default_value => 'localhost'),
  Optional[String]  $registry_username     = $candidate ? { undef => lookup('nest::build::registry_username', { 'default_value' => undef }), default => undef },
  Optional[String]  $registry_password     = $candidate ? { undef => lookup('nest::build::registry_password', { 'default_value' => undef }), default => undef },
  String            $registry_password_var = 'NEST_REGISTRY_PASSWORD',
  Optional[Hash]    $repo_revisions        = undef,
) {
  if $candidate != undef {
    assert_type(Pattern[/\A[a-z0-9][a-z0-9._-]{0,100}\z/], $candidate)
    assert_type(Enum['zen5'], $cpu)
    assert_type(Pattern[/\A[a-z0-9][a-z0-9.:-]*\z/], $registry)
    unless $build and $deploy and $init and $from_image and $repo_revisions and $registry != 'localhost' and $tag == undef {
      fail('Agent candidate requires build, deploy, init, exact base, frozen repositories, no tag override and a remote registry')
    }
    unless $registry_username == undef and $registry_password == undef {
      fail('Agent candidate requires existing runner registry authentication, not credential parameters')
    }
  }

  $target = Target.new(name => $container, uri => "podman://${container}")
  $image_tag = $candidate ? {
    undef   => pick($tag, 'latest'),
    default => undef,
  }

  run_plan('nest::build::tool', {
    container             => $container,
    cpu                   => $cpu,
    tool                  => 'agent',
    tag                   => $image_tag,
    build                 => $build,
    deploy                => false,
    emerge_default_opts   => $emerge_default_opts,
    from_image            => $from_image,
    id                    => $id,
    init                  => $init,
    makeopts              => $makeopts,
    qemu_user_targets     => $qemu_user_targets,
    refresh               => $refresh,
    repo_revisions        => $repo_revisions,
  })

  if $build {
    # Keep a fast runtime smoke after the standard tool-image configuration pass
    # so agent-specific packages such as glab are installed before publishing.
    run_command("podman start ${container}", 'localhost', 'Start build container')
    run_command("podman exec ${container} /bin/zsh -lc 'print nest-agent-terminal-smoke'", 'localhost', 'Smoke test terminal shell in agent image')
    run_command("podman exec ${container} /bin/zsh -lc 'glab --version'", 'localhost', 'Verify glab in agent image')
    run_command("podman exec ${container} /bin/zsh -lc 'git --version'", 'localhost', 'Verify Git in agent image')
    if $repo_revisions != undef {
      run_script('nest/build/freeze-repos.py', $target, arguments => ['check', $repo_revisions['gentoo'], $repo_revisions['nest'], $repo_revisions['haskell']])
    }
    run_command("podman stop ${container}", 'localhost', 'Stop build container')
  }

  if $candidate != undef {
    $image = "${registry}/nest/tools/agent:candidate-${candidate}"
    run_command("podman commit --change CMD=/bin/zsh ${container} ${image}", 'localhost', 'Commit checked Agent candidate')
    $image_ref = run_script('nest/build/publish-image.sh', 'localhost', arguments => [$image]).first.value['stdout'].strip
    assert_type(Pattern[/\A[a-z0-9][a-z0-9._:\/-]*@sha256:[0-9a-f]{64}\z/], $image_ref)
    unless $image_ref.split('@')[0] == "${registry}/nest/tools/agent" {
      fail('Agent candidate publisher returned a different repository')
    }
    return({ 'image' => $image_ref })
  } elsif $deploy {
    run_plan('nest::build::tool', {
      container             => $container,
      cpu                   => $cpu,
      tool                  => 'agent',
      tag                   => $image_tag,
      build                 => false,
      deploy                => true,
      init                  => false,
      registry              => $registry,
      registry_username     => $registry_username,
      registry_password     => $registry_password,
      registry_password_var => $registry_password_var,
    })
  }
}
