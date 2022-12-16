class nest::base::portage {
  class { 'portage':
    eselect_ensure => installed,
  }

  # Remove unused directories created by Class[portage]
  File <|
    title == '/etc/portage/package.keywords' or
    title == '/etc/portage/postsync.d'
  |> {
    ensure => absent,
    force  => true,
  }

  # Purge all other unmanaged configs
  File <|
    title == '/etc/portage/package.mask' or
    title == '/etc/portage/package.unmask' or
    title == '/etc/portage/package.use'
  |> {
    purge   => true,
    recurse => true,
    force   => true,
  }

  file {
    default:
      ensure  => directory,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      purge   => true,
      recurse => true,
      force   => true,
    ;

    [
      '/etc/portage/env',
      '/etc/portage/package.accept_keywords',
      '/etc/portage/package.env',
      '/etc/portage/profile',
      '/etc/portage/profile/package.use.force',
      '/etc/portage/profile/package.use.mask',
    ]:
      # use defaults
    ;

    [
      '/etc/portage/package.accept_keywords/default',
      '/etc/portage/package.env/default',
      '/etc/portage/package.mask/default',
      '/etc/portage/package.unmask/default',
      '/etc/portage/package.use/default',
      '/etc/portage/profile/package.provided',
    ]:
      ensure => file,
    ;

    '/etc/portage/patches':
      source => 'puppet:///modules/nest/portage/patches',
    ;
  }



  #
  # make.conf
  #
  $makejobs_memory     = ceiling($facts['memory']['system']['total_bytes'] / (512.0 * 1024 * 1024))
  $makejobs_distcc     = $nest::distcc_hosts.reduce($nest::concurrency) |$memo, $host| { $memo + $host[1] }
  $makejobs            = min($makejobs_memory, $makejobs_distcc)
  $mergejobs           = $nest::concurrency
  $loadlimit           = $nest::concurrency + 1
  $emerge_default_opts = pick($facts['emerge_default_opts'], "--jobs=${mergejobs} --load-average=${loadlimit}")
  $makeopts            = pick($facts['makeopts'], "-j${makejobs} -l${loadlimit}")

  $features = $facts['is_container'] ? {
    true    => ['distcc', '-ipc-sandbox', '-pid-sandbox', '-network-sandbox', '-usersandbox'],
    default => ['distcc'],
  }

  portage::makeconf {
    'emerge_default_opts':
      content => "\${EMERGE_DEFAULT_OPTS} ${emerge_default_opts}",
    ;

    'features':
      content => $features,
    ;

    'makeopts':
      content => $makeopts,
    ;
  }

  # Don't timeout rebuilding packages
  Exec <| title == 'changed_makeconf' |> {
    timeout => 0,
  }



  #
  # Repositories
  #
  contain 'nest::lib::repos'

  nest::lib::repo {
    'gentoo':
      url     => 'https://gitlab.james.tl/nest/gentoo/portage.git',
      default => true,
    ;

    'nest':
      url      => 'https://gitlab.james.tl/nest/overlay.git',
      unstable => true,
    ;
  }



  #
  # Package environments and properties
  #

  file { '/etc/portage/env/no-buildpkg.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "FEATURES=\"-buildpkg\"\n",
  }

  # xvid incorrectly passes `-mcpu` as `-mtune` which doesn't accept `+crypto`
  $cflags_no_crypto = regsubst($facts['portage_cflags'], '\+crypto', '')
  if $cflags_no_crypto != $facts['portage_cflags'] {
    file { '/etc/portage/env/no-crypto.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "CFLAGS=\"${cflags_no_crypto}\"\nCXXFLAGS=\"\${CFLAGS}\"\n",
    }
    ->
    package_env { 'media-libs/xvid':
      env => 'no-crypto.conf',
    }
  }

  # Workaround https://bugs.gentoo.org/666560
  if $facts['is_container'] and !$facts['profile']['architecture'] == 'amd64' {
    file { '/etc/portage/env/no-sandbox.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "FEATURES=\"-sandbox\"\n",
    }
    ->
    package_env { [
      'app-containers/conmon',
      'app-containers/podman',
      'sys-cluster/kubectl',
      'sys-libs/glibc',
    ]:
      env => 'no-sandbox.conf',
    }
  }

  if $facts['is_container'] {
    file { '/etc/portage/profile/profile.bashrc':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "DONT_MOUNT_BOOT=1\n",
    }
  }

  # Create portage package properties rebuild affected packages
  create_resources(package_accept_keywords, $nest::package_keywords, {
    'accept_keywords' => '~*',
    'before'          => Class['portage'],
  })
  create_resources(package_env, $nest::package_env, {
    'before' => Class['portage']
  })

  # Purge unmanaged portage package properties
  resources { [
    'package_accept_keywords',
    'package_env',
    'package_mask',
    'package_unmask',
    'package_use',
  ]:
    purge  => true,
    before => Class['portage'],
  }
}
