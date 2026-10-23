# @summary Build Puppet Development Kit
#
# Use bin/build script to run this plan!
#
# @param container Build container name
# @param cpu Build for this CPU architecture
# @param tag Image tag to publish; defaults to cpu
# @param build Build the image
# @param candidate Frozen candidate token; requires complete inputs and PDK smoke before publication
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
plan nest::build::pdk (
  String            $container,
  String            $cpu,
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
    assert_type(Enum['haswell', 'cortex-a53', 'sifive-u74'], $cpu)
    assert_type(Pattern[/\A[a-z0-9][a-z0-9.:-]*\z/], $registry)
    unless $build and $deploy and $init and $from_image and $repo_revisions and $registry != 'localhost' and $tag == undef {
      fail('PDK candidate requires build, deploy, init, exact base, frozen repositories, no tag override and a remote registry')
    }
    unless $registry_username == undef and $registry_password == undef {
      fail('PDK candidate requires existing runner registry authentication, not credential parameters')
    }
  }
  $target = Target.new(name => $container, uri => "podman://${container}")

  $puppetcore_gem_source = system::env('GEM_SOURCE_PUPPETCORE')
  $puppet_forge_token    = system::env('PUPPET_FORGE_TOKEN')
  $puppetcore_env_vars   = {
    'NEST_PDK_OFFLINE'                         => 'false',
    'BUNDLE_RUBYGEMS___PUPPETCORE__PUPPET__COM' => "forge-key:${puppet_forge_token}",
    'GEM_SOURCE_PUPPETCORE'                     => $puppetcore_gem_source,
    'PUPPET_FORGE_TOKEN'                        => $puppet_forge_token,
  }

  run_plan('nest::build::tool', {
    container             => $container,
    cpu                   => $cpu,
    tool                  => 'pdk',
    build                 => $build,
    tag                   => $tag,
    deploy                => false,
    emerge_default_opts   => $emerge_default_opts,
    extra_volumes         => ['/etc/gemrc:/etc/gemrc:ro'],
    from_image            => $from_image,
    id                    => $id,
    init                  => $init,
    makeopts              => $makeopts,
    qemu_user_targets     => $qemu_user_targets,
    refresh               => $refresh,
    repo_revisions        => $repo_revisions,
  })

  if $build {
    run_command("podman start ${container}", 'localhost', 'Start build container')

    # Refresh images retain their empty runtime working directory.
    # PDK requires the destination to be absent when generating a module.
    run_command('sh -c "cd / && rm -rf /module && pdk new module --skip-interview build /module"', $target, 'Create test module', _env_vars => $puppetcore_env_vars)
    run_command('sh -c "cd /module && pdk new class smoke && pdk new task smoke && bundle install && pdk validate && pdk test unit --tests=spec/classes/smoke_spec.rb"', $target, 'Resolve dependencies, validate class and task, and test generated class', _env_vars => $puppetcore_env_vars)
    run_command('rm -rf /module && mkdir /module', $target, 'Clean up test module')

    # Resolve the actual supported module, not just the generated smoke module.
    # The plan is run from the committed Nest project root by bin/build/CI.
    run_command("bash -o pipefail -c 'git archive HEAD | podman cp - ${container}:/module'", 'localhost', 'Copy committed Nest module inputs')
    run_command('sh -c "cd /module && NEST_PDK_OFFLINE=false ruby /opt/pdk-cache-nest.rb"', $target, 'Resolve and retain the Nest PDK closure and source lock', _env_vars => $puppetcore_env_vars)
    run_command('rm -rf /module && mkdir /module', $target, 'Clean up Nest build inputs')

    if $repo_revisions != undef {
      run_script('nest/build/freeze-repos.py', $target, arguments => ['check', $repo_revisions['gentoo'], $repo_revisions['nest'], $repo_revisions['haskell']])
    }
    run_command("podman stop ${container}", 'localhost', 'Stop build container')
  }

  if $candidate != undef {
    $image = "${registry}/nest/tools/pdk:candidate-${candidate}"
    run_command("podman commit --change CMD=/bin/zsh --change ENV=PDK_DISABLE_ANALYTICS=true --change ENV=NEST_PDK_OFFLINE=true --change WORKDIR=/module ${container} ${image}", 'localhost', 'Commit checked PDK candidate')
    $image_ref = run_script('nest/build/publish-image.sh', 'localhost', arguments => [$image]).first.value['stdout'].strip
    assert_type(Pattern[/\A[a-z0-9][a-z0-9._:\/-]*@sha256:[0-9a-f]{64}\z/], $image_ref)
    unless $image_ref.split('@')[0] == "${registry}/nest/tools/pdk" {
      fail('PDK candidate publisher returned a different repository')
    }
    return({ 'image' => $image_ref })
  } elsif $deploy {
    run_plan('nest::build::tool', {
      container             => $container,
      cpu                   => $cpu,
      tool                  => 'pdk',
      build                 => false,
      tag                   => $tag,
      deploy                => true,
      image_changes         => ['ENV=PDK_DISABLE_ANALYTICS=true', 'ENV=NEST_PDK_OFFLINE=true', 'WORKDIR=/module'],
      init                  => false,
      registry              => $registry,
      registry_username     => $registry_username,
      registry_password     => $registry_password,
      registry_password_var => $registry_password_var,
    })
  }
}
