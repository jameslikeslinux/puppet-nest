class nest::base::portage {
  $input_devices_ensure = $::nest::input_devices ? {
    undef   => absent,
    default => undef,
  }

  $video_cards_ensure = $::nest::video_cards ? {
    undef   => absent,
    default => undef,
  }

  $use_ensure = $::nest::use_combined ? {
    []      => absent,
    default => undef,
  }

  $makejobs_memory = ceiling($facts['memory']['system']['total_bytes'] / (512.0 * 1024 * 1024))
  $makejobs_memory_heavy = ceiling($facts['memory']['system']['total_bytes'] / (4096.0 * 1024 * 1024))
  $makejobs_distcc = $::nest::distcc_hosts.reduce($::nest::processorcount) |$memo, $host| { $memo + $host[1] }

  $makejobs = min($makejobs_memory, $makejobs_distcc)
  $makejobs_heavy = min($makejobs_memory_heavy, $::nest::processorcount)

  $loadlimit = $::nest::processorcount + 1
  $makeopts = "-j${makejobs} -l${loadlimit}"
  $makeopts_heavy = "-j${makejobs_heavy} -l${loadlimit}"

  # Basically, this goes:
  #  1. Install portage stuff, like eselect
  #  2. eselect profile/change make.conf
  #  3. Rebuild packages as necessary (Exec[changed_makeconf])
  class { '::portage':
    eselect_ensure => installed,
  }

  Package_accept_keywords <| title == 'sys-apps/portage' |> {
    ensure  => present,
    version => '~3.0.2'
  }

  eselect { 'profile':
    set     => $::nest::gentoo_profile,
    require => Package['app-admin/eselect'],
    before  => Class['::portage'],
  }

  # Mesa has circular dependencies when USE=vaapi is set, so just build it
  # before any USE variables are set and it will eventually converge.
  if $::role == 'workstation' {
    exec { '/usr/bin/emerge --oneshot media-libs/mesa':
      timeout     => 0,
      refreshonly => true,
      subscribe   => Eselect['profile'],
      before      => Portage::Makeconf['use'],
    }
  }

  if $facts['os']['architecture'] =~ /^(arm|aarch64)/ {
    if $facts['virtual'] == 'lxc' {
      $sandbox_features = ['-sandbox', '-usersandbox', '-pid-sandbox', '-network-sandbox']
    } else {
      $sandbox_features = []
    }

    $cpu_flags_x86_ensure = 'absent'
  } else {
    $sandbox_features = []
    $cpu_flags_x86_ensure = 'present'
  }

  $cflags_arch = $::nest::cflags ? {
    /-m(?:arch|cpu)=(\S+)/ => $1,
    default                => 'unknown',
  }

  portage::makeconf {
    'accept_license':
      content => '*';
    'cflags':
      content => $::nest::cflags;
    'cxxflags':
      content => $::nest::cflags;
    'cpu_flags_x86':
      ensure  => $cpu_flags_x86_ensure,
      content => $::nest::cpu_flags_x86;
    'distdir':
      content => '/nest/portage/distfiles';
    'emerge_default_opts':
      content => '${EMERGE_DEFAULT_OPTS} --usepkg';
    'features':
      content => ['buildpkg', 'distcc', 'splitdebug'] + $sandbox_features;
    'input_devices':
      ensure  => $input_devices_ensure,
      content => $::nest::input_devices;
    'makeopts':
      content => $makeopts;
    'pkgdir':
      content => "/nest/portage/packages/${::architecture}-${::role}.${cflags_arch}";
    'use':
      ensure  => $use_ensure,
      content => $::nest::use_combined;
    'video_cards':
      ensure  => $video_cards_ensure,
      content => $::nest::video_cards;
  }

  $cflags_no_debug  = regsubst($::nest::cflags, '\s?-g(gdb)?', '')
  $cflags_no_crypto = regsubst($::nest::cflags, '\+crypto', '')
  $cflags_no_crypto_ensure = $cflags_no_crypto ? {
    $::nest::cflags => 'absent',
    default         => 'present',
  }

  file {
    default:
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
      before => Class['::portage'],
    ;

    '/etc/portage/env':
      ensure => directory,
    ;

    '/etc/portage/env/no-debug.conf':
      content => "CFLAGS='${cflags_no_debug}'\nCXXFLAGS='${cflags_no_debug}'\n",
    ;

    '/etc/portage/env/no-crypto.conf':
      ensure  => $cflags_no_crypto_ensure,
      content => "CFLAGS='${cflags_no_crypto}'\nCXXFLAGS='${cflags_no_crypto}'\n",
    ;

    '/etc/portage/env/no-local.conf':
      ensure => absent,
    ;

    '/etc/portage/env/heavy.conf':
      content => "MAKEOPTS='${makeopts_heavy}'\n",
    ;
  }

  # xvid incorrectly passes `-mcpu` as `-mtune` which doesn't accept `+crypto`
  package_env { 'media-libs/xvid':
    ensure => $cflags_no_crypto_ensure,
    env    => 'no-crypto.conf',
  }

  package_env { $::nest::heavy_packages_hiera:
    env => 'heavy.conf',
  }

  $haskell_heavy_ensure = $::platform ? {
    'pinebookpro' => present,
    default       => absent,
  }

  file { '/etc/portage/package.env/haskell':
    ensure  => $haskell_heavy_ensure,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "dev-haskell/* heavy.conf\n",
  }

  # Create portage package properties rebuild affected packages
  create_resources(package_accept_keywords, $::nest::package_keywords_hiera, { 'before' => Class['::portage'] })
  create_resources(package_mask, $::nest::package_mask_hiera, { 'before' => Class['::portage'] })
  create_resources(package_use, $::nest::package_use_hiera, { 'notify' => Class['::portage'] })

  # Purge unmanaged portage package properties
  resources {
    default:
      purge => true,
    ;

    'package_accept_keywords':
      before => Class['::portage'],
    ;

    'package_env':
      before => Class['::portage'],
    ;

    'package_mask':
      before => Class['::portage'],
    ;

    'package_use':
      notify => Class['::portage'],
    ;
  }


  # Don't let eix-sync override my tmux window title
  file { '/etc/eixrc/10-disable-statusline':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "NOSTATUSLINE=true\n",
  }

  file { '/etc/portage/patches':
    ensure  => directory,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/nest/portage/patches',
    recurse => true,
    force   => true,
    purge   => true,
  }

  file { '/etc/portage/profile':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  # Enable libzfs USE flag for GRUB
  # XXX: This could be made more generic if needed
  $use_mask_content = @(EOT)
    -bundled-libjpeg-turbo
    -input_devices_libinput
    -gnuefi
    -libzfs
    -zfs
    | EOT

  file { '/etc/portage/profile/use.mask':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $use_mask_content,
  }

  $repos_conf = @(EOT)
    [DEFAULT]
    main-repo = gentoo

    [gentoo]
    location = /var/cache/portage/gentoo
    sync-type = git
    sync-uri = https://github.com/iamjamestl/portage-gentoo.git
    sync-depth = 1
    auto-sync = yes

    [nest]
    location = /var/cache/portage/nest
    sync-type = git
    sync-uri = https://github.com/iamjamestl/portage-nest.git
    sync-depth = 1
    auto-sync = yes
    masters = gentoo
    | EOT

  if $::role == 'workstation' {
    # Speed up metadata resolution of haskell overlay in eix-sync
    # See: https://github.com/gentoo-haskell/gentoo-haskell/blob/master/README.rst
    $eix_conf_content = @("EOT")
      *
      @egencache --jobs=${::nest::processorcount} --repo=haskell --update --update-use-local-desc
      | EOT

    $repos_workstation = @(EOT)

      [haskell]
      location = /var/cache/portage/haskell
      sync-type = git
      sync-uri = https://github.com/iamjamestl/gentoo-haskell.git
      sync-depth = 1
      auto-sync = yes
      masters = gentoo
      | EOT

    $repos_workstation_ensure = 'present'
  } else {
    $eix_conf_content = "*\n"
    $repos_workstation_ensure = 'absent'
  }

  file { '/etc/portage/package.accept_keywords/kde':
    ensure  => absent,
  }

  file { '/etc/portage/package.accept_keywords/haskell':
    ensure  => $repos_workstation_ensure,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "*/*::haskell ~*\n",
  }

  file { '/etc/portage/package.accept_keywords/nest':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "*/*::nest ~*\n",
  }

  file { '/etc/portage/package.accept_keywords/tlp':
    ensure  => absent,
  }

  file { '/etc/eix-sync.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $eix_conf_content,
  }

  if $::nest::distcc_server or $::platform == 'pinebookpro' {
    $repos_crossdev = @(EOT)

      [crossdev]
      location = /var/cache/portage/crossdev
      auto-sync = no
      masters = gentoo
      | EOT

    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      [
        '/var/cache/portage/crossdev',
        '/var/cache/portage/crossdev/metadata',
        '/var/cache/portage/crossdev/profiles',
      ]:
        ensure => directory,
      ;

      '/var/cache/portage/crossdev/metadata/layout.conf':
        content => "masters = gentoo\nthin-manifests = true\n",
      ;

      '/var/cache/portage/crossdev/profiles/repo_name':
        content => "crossdev\n",
      ;
    }
  } else {
    file { '/var/cache/portage/crossdev':
      ensure  => absent,
      recurse => true,
      force   => true,
    }
  }

  file { '/etc/portage/repos.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "${repos_conf}${repos_workstation}${repos_crossdev}",
  }

  vcsrepo {
    default:
      ensure   => present,
      provider => git,
      force    => true,
      depth    => 1,
      notify   => Exec['/usr/bin/eix-update'],
    ;

    '/var/cache/portage/gentoo':
      source => 'https://github.com/iamjamestl/portage-gentoo.git',
    ;

    '/var/cache/portage/nest':
      source => 'https://github.com/iamjamestl/portage-overlay.git',
    ;

    '/var/cache/portage/haskell':
      ensure => $repos_workstation_ensure,
      source => 'https://github.com/iamjamestl/gentoo-haskell.git',
    ;

    '/var/cache/portage/tlp':
      ensure => absent,
    ;
  }

  exec { '/usr/bin/eix-update':
    refreshonly => true,
  }
}
