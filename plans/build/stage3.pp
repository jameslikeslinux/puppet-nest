# @summary Build complete images for specific hosts
#
# Use bin/build script to run this plan!
#
# @param container Build container name
# @param hostname Hostname of the image
# @param platform Build for this platform
# @param variant Build using this variant
# @param build Build the image
# @param deploy Deploy the image
# @param emerge_default_opts Override default emerge options (e.g. --jobs=4)
# @param hostroot Where the image gets deployed
# @param id Build ID
# @param identityroot Host identity input, separate from publication destination
# @param identity_ca_sha256 Independently approved public CA PEM digest, required for frozen catalogs
# @param init Initialize the build container
# @param makeopts Override make flags (e.g. -j4)
# @param puppet_environment Puppet environment to use for final configuration
# @param profile Switch to this profile
# @param qemu_user_targets CPU architectures to emulate
# @param rsync_private_key_var Environment variable for rsync private key
# @param repo_revisions Complete gentoo/nest/haskell commit pins; isolated repositories, no sync
# @param stage2_image Exact Stage2 image reference; defaults to platform/variant tag
# @param catalog_inputs Exact installed config executor source/base; use its local modules, not a served environment
plan nest::build::stage3 (
  String            $container,
  String            $hostname,
  String            $platform,
  String            $variant,
  Boolean           $build                 = true,
  Optional[String]  $cluster               = undef,
  Boolean           $deploy                = false,
  Optional[String]  $emerge_default_opts   = undef,
  String            $hostroot              = "/nest/hosts/${hostname}",
  Optional[Numeric] $id                    = undef,
  String            $identityroot          = $hostroot,
  Optional[String]  $identity_ca_sha256    = undef,
  Boolean           $init                  = true,
  Optional[String]  $makeopts              = undef,
  Optional[String]  $puppet_environment    = undef,
  Optional[String]  $profile               = undef,
  Array[String]     $qemu_user_targets     = lookup('nest::build::qemu_user_targets', default_value => []),
  String            $rsync_private_key_var = 'NEST_RSYNC_PRIVATE_KEY',
  Optional[Hash]    $repo_revisions        = undef,
  Optional[String]  $stage2_image          = undef,
  Optional[Hash]    $catalog_inputs        = undef,
) {
  if $catalog_inputs != undef {
    assert_type(Pattern[/\A[0-9a-f]{64}\z/], $identity_ca_sha256)
    assert_type(Struct[{
      'source' => Pattern[/\A[0-9a-f]{40}\z/],
      'base'   => Pattern[/\A[a-z0-9][a-z0-9._:\/-]*@sha256:[0-9a-f]{64}\z/],
    }], $catalog_inputs)
    unless $build and $init and $repo_revisions != undef and $puppet_environment == undef {
      fail('Frozen Stage 3 catalogs require build, init, frozen repositories and no served Puppet environment')
    }
    # This opt-in path runs inside the accepted /opt/nest executor project.
    # Its retained inventory includes both Nest checkouts and every module.
    $check_catalog = "python3 /opt/nest/scripts/nest-executor-inputs.py check --source ${catalog_inputs['source'].shellquote} --base ${catalog_inputs['base'].shellquote} > /dev/null"
  }
  if $repo_revisions != undef {
    assert_type(Struct[{
      'gentoo'  => Pattern[/\A[0-9a-f]{40}\z/],
      'nest'    => Pattern[/\A[0-9a-f]{40}\z/],
      'haskell' => Pattern[/\A[0-9a-f]{40}\z/],
    }], $repo_revisions)
    assert_type(Pattern[/\A[a-z0-9][a-z0-9._:\/-]*@sha256:[0-9a-f]{64}\z/], $stage2_image)
    unless $build and $init {
      fail('Frozen Stage 3 repositories require build, init and an exact Stage 2 base')
    }
    $repos_volume_arg = "--volume=${container}-frozen-repos:/var/db/repos:nocopy"
    $repo_args = [$repo_revisions['gentoo'], $repo_revisions['nest'], $repo_revisions['haskell']]
  } else {
    $repos_volume_arg = ''
  }
  $ssh_auth_sock = system::env('SSH_AUTH_SOCK')
  $target = Target.new(name => $hostname, uri => "podman://${container}")
  $base_image = $stage2_image ? {
    undef   => "nest/stage2/${variant}:${platform}",
    default => $stage2_image,
  }

  if $catalog_inputs != undef {
    run_command($check_catalog, 'localhost', 'Verify frozen catalog executor before initialization')
    # Frozen builds consume preprovisioned private identity; they must not create
    # or repair it, nor copy a root over that same source through legacy defaults.
    run_script('nest/build/check-stage3-paths.py', 'localhost', arguments => [$identityroot, $hostroot, $hostname, $identity_ca_sha256])
  }

  if $init {
    run_command("podman rm -f ${container}", 'localhost', 'Stop and remove existing build container')
    if $repo_revisions != undef {
      run_command("podman volume rm -f ${container}-frozen-repos", 'localhost', 'Remove previous isolated build repositories')
    }

    if !empty($ssh_auth_sock) and run_command("test -S ${ssh_auth_sock}", 'localhost', 'Check SSH_AUTH_SOCK', '_catch_errors' => true).ok {
      $ssh_auth_sock_volume = "--volume=${ssh_auth_sock}:${ssh_auth_sock}:ro"
    } else {
      $ssh_auth_sock_volume = ''
    }

    $podman_create_cmd = @("CREATE"/L)
      podman create \
      --init \
      --hostname=${hostname} \
      --name=${container} \
      --no-hosts \
      --pull=always \
      --volume=/falcon:/falcon \
      --volume=/nest:/nest \
      ${repos_volume_arg} \
      ${ssh_auth_sock_volume} \
      ${qemu_user_targets.map |$arch| { "--volume=/usr/bin/qemu-${arch}:/usr/bin/qemu-${arch}:ro" }.join(' ')} \
      ${base_image.shellquote} \
      sleep infinity
      | CREATE

    run_command($podman_create_cmd, 'localhost', 'Create build container')
  }

  if $build {
    run_command("podman start ${container}", 'localhost', 'Start build container')

    if $repo_revisions != undef {
      run_script('nest/build/freeze-repos.py', $target, arguments => ['prepare'] + $repo_args)
    }
    apply_prep($target)

    # Preserve and restore host identity info
    apply($target, '_description' => 'Set up host identity info') {
      if $catalog_inputs == undef {
        file { $identityroot:
          ensure => directory,
          mode   => '0555',
          owner  => 'root',
          group  => 'root',
        }
        ->
        exec { 'systemd-machine-id-setup':
          command => "/usr/bin/systemd-machine-id-setup --root=${identityroot.shellquote}",
          creates => "${identityroot}/etc/machine-id",
          before  => File['/etc/machine-id'],
        }

        file {
          "${identityroot}/etc/puppetlabs":
            ensure => directory,
            mode   => '0755',
            owner  => 'root',
            group  => 'root',
          ;

          "${identityroot}/etc/puppetlabs/puppet":
            ensure => directory,
            mode   => '0750',
            owner  => 'root',
            group  => 'puppet',
          ;

          "${identityroot}/etc/puppetlabs/puppet/ssl":
            ensure => directory,
            mode   => '0771',
            owner  => 'puppet',
            group  => 'puppet',
            before => File['/etc/puppetlabs/puppet/ssl'],
          ;
        }
      }

      file { '/etc/machine-id':
        source => "${identityroot}/etc/machine-id",
      }
      ->
      # Puppet Agent will correct permissions on these files
      file { '/etc/puppetlabs/puppet/ssl':
        ensure  => directory,
        source  => "${identityroot}/etc/puppetlabs/puppet/ssl",
        recurse => true,
      }

      if $cluster {
        file { '/etc/puppetlabs/puppet/csr_attributes.yaml':
          mode    => '0640',
          owner   => 'root',
          group   => 'puppet',
          content => {
            'extension_requests' => {
              'pp_cluster' => $cluster,
            },
          }.stdlib::to_yaml,
        }
      }
    }.nest::print_report

    if $repo_revisions == undef {
      run_command('eix-sync -aq', $target, 'Sync Portage repos')
    }

    if $profile {
      run_command("eselect profile set nest:${profile}", $target, "Switch to profile ${profile}")
    }

    # Set up the build environment
    add_facts($target, {
      'build'               => 'stage3',
      'emerge_default_opts' => $emerge_default_opts,
      'makeopts'            => $makeopts,
    })

    # Configure Portage and Puppet
    run_command("sh -c 'echo profile > /.apply_tags'", $target, 'Set Puppet tags for profile run')
    apply($target, '_description' => 'Configure the profile') { include nest }.nest::print_report
    run_command('rm /.apply_tags', $target, 'Clear Puppet apply settings')
    if $repo_revisions != undef {
      run_script('nest/build/freeze-repos.py', $target, arguments => ['check'] + $repo_args)
    }

    # Make the system consistent with the profile
    run_command('emerge --info', $target, 'Show Portage configuration')
    run_command('emerge --deep --newuse --update --verbose --with-bdeps=y @world', $target, 'Install packages')
    run_command('emerge --depclean', $target, 'Remove unused packages')

    # Apply the main configuration
    if $catalog_inputs != undef {
      run_command($check_catalog, 'localhost', 'Verify frozen catalog executor before configuration')
      run_script('nest/build/check-stage3-paths.py', 'localhost', arguments => [$identityroot, $hostroot, $hostname, $identity_ca_sha256])
      # Bolt compiles from this exact executor project/module inventory. Never
      # fetch a newer catalog from a mutable server environment in frozen mode.
      apply($target, '_description' => 'Configure the host image from frozen local modules') { include nest }.nest::print_report
      run_command($check_catalog, 'localhost', 'Verify frozen catalog executor after configuration')
      run_script('nest/build/check-stage3-paths.py', 'localhost', arguments => [$identityroot, $hostroot, $hostname, $identity_ca_sha256])
    } else {
      if !empty($puppet_environment) {
        $puppet_environment_args = ['--environment', $puppet_environment]
      } else {
        $puppet_environment_args = []
      }
      $puppet_cmd = ['puppet', 'agent', $puppet_environment_args, '--test'].flatten.shellquote
      $puppet_script = "${puppet_cmd} || [ \$? -eq 2 ]"
      run_command("sh -c ${puppet_script.shellquote}", $target, 'Configure the host image', '_env_vars' => {
        'FACTER_build' => 'stage3',
      })
    }
    if $repo_revisions != undef {
      run_script('nest/build/freeze-repos.py', $target, arguments => ['check'] + $repo_args)
    }

    run_command("podman stop ${container}", 'localhost', 'Stop build container')
  }

  if $deploy {
    run_command("podman start ${container}", 'localhost', 'Start build container')

    $rsync_script = @("RSYNC"/$)
      () {
        rsync -e "ssh -i \$1" \
          --archive --acls --hard-links --xattrs \
          --delete \
          --delete-excluded \
          --exclude='/run/**' \
          --exclude='/tmp/**' \
          --info=stats2 \
          --one-file-system \
          / root@falcon:${hostroot.shellquote}
      } =(<<< \$SSH_PRIVATE_KEY)
      | RSYNC

    run_command("zsh -c ${rsync_script.shellquote}", $target, 'Rsync the image', '_env_vars' => {
      'SSH_AUTH_SOCK'   => $ssh_auth_sock,
      'SSH_PRIVATE_KEY' => system::env($rsync_private_key_var),
    })

    run_command("podman stop ${container}", 'localhost', 'Stop build container')
  }
}
