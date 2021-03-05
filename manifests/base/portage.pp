class nest::base::portage {
  $python = regsubst($facts['portage_python_single_target'], '_', '.')

  class { 'portage':
    eselect_ensure => installed,
  }
  ->
  exec {
    'eselect-python-cleanup':
      command => '/usr/bin/eselect python cleanup',
      onlyif  => '/usr/bin/eselect --brief python list | /bin/grep uninstalled',
    ;

    'eselect-python-set':
      command => "/usr/bin/eselect python set ${python.shellquote}",
      unless  => "/usr/bin/eselect --brief python show | /bin/grep ${python.shellquote}",
    ;
  }

  # Remove unused directories created by Class[portage]
  File <|
    title == '/etc/portage/package.keywords' or
    title == '/etc/portage/package.mask' or
    title == '/etc/portage/package.unmask' or
    title == '/etc/portage/postsync.d'
  |> {
    ensure => absent,
    force  => true,
  }

  # Purge all other unmanaged configs
  File <| title == '/etc/portage/package.use' |> {
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
    ]:
      # use defaults
    ;

    [
      '/etc/portage/package.accept_keywords/default',
      '/etc/portage/package.env/default',
      '/etc/portage/package.use/default',
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
  $makejobs_distcc     = $::nest::distcc_hosts.reduce($::nest::concurrency) |$memo, $host| { $memo + $host[1] }
  $makejobs            = min($makejobs_memory, $makejobs_distcc)
  $loadlimit           = $::nest::concurrency + 1
  $emerge_default_opts = pick($facts['emerge_default_opts'], "--jobs=${::nest::concurrency} --load-average=${loadlimit}")
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
  if $facts['is_container'] and $facts['architecture'] != 'amd64' {
    file { '/etc/portage/env/no-sandbox.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "FEATURES=\"-sandbox\"\n",
    }
    ->
    package_env { 'sys-libs/glibc':
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

  # GHC 8.10 or LLVM 9 hangs or crashes with big.LITTLE flags under qemu-user
  $cflags_no_big_little = regsubst($facts['portage_cflags'], '\.cortex-\w+', '')
  if $cflags_no_big_little != $facts['portage_cflags'] {
    $haskell_env = @(HASKELL_ENV)
      dev-haskell/* no-big-little.conf
      dev-lang/ghc no-big-little.conf
      x11-misc/taffybar no-big-little.conf
      x11-wm/xmonad no-big-little.conf
      x11-wm/xmonad-contrib no-big-little.conf
      | HASKELL_ENV

    file { '/etc/portage/env/no-big-little.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "CFLAGS=\"${cflags_no_big_little}\"\nCXXFLAGS=\"\${CFLAGS}\"\n",
    }
    ->
    file { '/etc/portage/package.env/haskell':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $haskell_env,
    }
  }

  # Create portage package properties rebuild affected packages
  create_resources(package_accept_keywords, $::nest::package_keywords, { 'before' => Class['::portage'] })
  create_resources(package_env, $::nest::package_env, { 'before' => Class['::portage'] })

  # Purge unmanaged portage package properties
  resources { [
    'package_accept_keywords',
    'package_env',
    'package_use',
  ]:
    purge  => true,
    before => Class['::portage'],
  }
}
