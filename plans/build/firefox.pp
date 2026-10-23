# @summary Build Firefox/KasmVNC browser.eyrie tool image
#
# Use bin/build script to run this plan.
#
# @param container Build container name
# @param cpu Build for this CPU architecture
# @param tag Image tag to publish; defaults to latest
# @param base_cpu Stage1 workstation CPU tag (no zen5-workstation output exists)
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
plan nest::build::firefox (
  String            $container,
  String            $cpu                   = 'haswell',
  Optional[String]  $tag                   = undef,
  String            $base_cpu              = 'haswell',
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
    assert_type(Enum['haswell'], $base_cpu)
    assert_type(Pattern[/\A[a-z0-9][a-z0-9.:-]*\z/], $registry)
    unless $build and $deploy and $init and $from_image and $repo_revisions and $registry != 'localhost' and $tag == undef {
      fail('Firefox candidate requires build, deploy, init, exact base, frozen repositories, no tag override and a remote registry')
    }
    unless $registry_username == undef and $registry_password == undef {
      fail('Firefox candidate requires existing runner registry authentication, not credential parameters')
    }
  }
  $image_tag = $candidate ? { undef => pick($tag, 'latest'), default => undef }

  run_plan('nest::build::tool', {
    container           => $container,
    cpu                 => $cpu,
    tool                => 'firefox',
    tag                 => $image_tag,
    base_variant        => 'workstation',
    base_cpu            => $base_cpu,
    build               => $build,
    deploy              => false,
    emerge_default_opts => $emerge_default_opts,
    from_image          => $from_image,
    id                  => $id,
    init                => $init,
    makeopts            => $makeopts,
    qemu_user_targets   => $qemu_user_targets,
    refresh             => $refresh,
    repo_revisions      => $repo_revisions,
    registry            => $registry,
    registry_username   => $registry_username,
    registry_password   => $registry_password,
    registry_password_var => $registry_password_var,
    image_changes       => [
      'CMD=/usr/local/bin/nest-firefox-browser',
      'WORKDIR=/home/kasm-user',
    ],
  })

  if $build {
    $target = Target.new(name => $container, uri => "podman://${container}")
    run_command("podman start ${container}", 'localhost', 'Start build container for smoke test')
    run_command('/opt/nest/firefox/bin/smoke-firefox.sh', $target, 'Smoke test Portage Firefox in headless mode')
    if $repo_revisions != undef {
      run_script('nest/build/freeze-repos.py', $target, arguments => ['check', $repo_revisions['gentoo'], $repo_revisions['nest'], $repo_revisions['haskell']])
    }
    run_command("podman stop ${container}", 'localhost', 'Stop build container after smoke test')
  }

  if $candidate != undef {
    $image = "${registry}/nest/tools/firefox:candidate-${candidate}"
    run_command("podman commit --change CMD=/usr/local/bin/nest-firefox-browser --change WORKDIR=/home/kasm-user ${container} ${image}", 'localhost', 'Commit checked Firefox candidate')
    $image_ref = run_script('nest/build/publish-image.sh', 'localhost', arguments => [$image]).first.value['stdout'].strip
    assert_type(Pattern[/\A[a-z0-9][a-z0-9._:\/-]*@sha256:[0-9a-f]{64}\z/], $image_ref)
    unless $image_ref.split('@')[0] == "${registry}/nest/tools/firefox" {
      fail('Firefox candidate publisher returned a different repository')
    }
    return({ 'image' => $image_ref })
  } elsif $deploy {
    run_plan('nest::build::tool', {
      container             => $container,
      cpu                   => $cpu,
      tool                  => 'firefox',
      tag                   => $image_tag,
      build                 => false,
      deploy                => true,
      init                  => false,
      registry              => $registry,
      registry_username     => $registry_username,
      registry_password     => $registry_password,
      registry_password_var => $registry_password_var,
      image_changes         => [
        'CMD=/usr/local/bin/nest-firefox-browser',
        'WORKDIR=/home/kasm-user',
      ],
    })
  }
}
