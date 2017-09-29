class nest::profile::base::portage {
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

  $makejobs_by_memory = ceiling($memory['system']['total_bytes'] / (512.0 * 1024 * 1024))
  $makejobs_distcc = $::nest::distcc_hosts.reduce($::nest::processorcount + 1) |$memo, $host| { $memo + $host[1] + 1 }

  $makejobs_distcc_min = ($makejobs_by_memory < $makejobs_distcc) ? {
    true    => $makejobs_by_memory,
    default => $makejobs_distcc,
  }

  $loadlimit = $::nest::processorcount + 1
  $makeopts = "-j${makejobs_distcc_min} -l${loadlimit}"


  # Basically, this goes:
  #  1. Install portage stuff, like eselect
  #  2. eselect profile/change make.conf
  #  3. Rebuild packages as necessary (Exec[changed_makeconf])
  class { '::portage':
    eselect_ensure => installed,
  }

  eselect { 'profile':
    set     => $::nest::gentoo_profile,
    require => Package['app-admin/eselect'],
    before  => Class['::portage'],
  }

  $portage_features = size($::nest::distcc_hosts) ? {
    0       => ['buildpkg', 'distcc', 'splitdebug'],
    default => ['buildpkg', 'distcc', 'distcc-pump', 'splitdebug'],
  }

  portage::makeconf {
    'accept_license':
      content => '*';
    'cflags':
      content => $::nest::cflags;
    'cxxflags':
      content => $::nest::cflags;
    'cpu_flags_x86':
      content => $::nest::cpu_flags_x86;
    'distdir':
      content => '/nest/portage/distfiles';
    'emerge_default_opts':
      content => '${EMERGE_DEFAULT_OPTS} --usepkg';
    'features':
      content => $portage_features;
    'input_devices':
      content => $::nest::input_devices,
      ensure  => $input_devices_ensure;
    'makeopts':
      content => $makeopts;
    'pkgdir':
      content => "/nest/portage/packages/${::architecture}-${::nest['profile']}";
    'use':
      content => $::nest::use_combined,
      ensure  => $use_ensure;
    'video_cards':
      content => $::nest::video_cards,
      ensure  => $video_cards_ensure;
  }

  $cflags_no_debug = regsubst($::nest::cflags, '\s?-g(gdb)?', '')

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
  }

  # Create portage package properties rebuild affected packages
  create_resources(package_keywords, $::nest::package_keywords_hiera, { 'before' => Class['::portage'] })
  create_resources(package_use, $::nest::package_use_hiera, { 'notify' => Class['::portage'] })


  # Don't let eix-sync override my tmux window title
  file { '/etc/eixrc/10-disable-statusline':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "NOSTATUSLINE=true\n",
  }

  # Speed up metadata resolution of haskell overlay in eix-sync
  # See: https://github.com/gentoo-haskell/gentoo-haskell/blob/master/README.rst
  $eix_conf_content = @("EOT")
    *
    @egencache --jobs=${loadlimit} --repo=haskell --update --update-use-local-desc
    | EOT

  file { '/etc/eix-sync.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $eix_conf_content,
  }


  $kde_keywords_content = @(EOT)
    dev-qt/*:5
    kde-*/*:5
    | EOT

  file { '/etc/portage/package.keywords/kde':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $kde_keywords_content,
  }

  file { '/etc/portage/package.keywords/haskell':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "*/*::haskell ~amd64\n",
  }

  file { [
    '/etc/portage/patches',
    '/etc/portage/profile'
  ]:
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    purge   => true,
    recurse => true,
  }

  # Enable libzfs USE flag for GRUB
  # XXX: This could be made more generic if needed
  $use_mask_content = @(EOT)
    -libzfs
    -input_devices_libinput
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
    auto-sync = yes

    [nest]
    location = /var/cache/portage/nest
    sync-type = git
    sync-uri = https://github.com/iamjamestl/portage-nest.git
    auto-sync = yes
    masters = gentoo

    [haskell]
    location = /var/cache/portage/haskell
    sync-type = git
    sync-uri = https://github.com/iamjamestl/gentoo-haskell.git
    auto-sync = yes
    masters = gentoo
    | EOT

  file { '/etc/portage/repos.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $repos_conf,
  }

  vcsrepo { '/var/cache/portage/gentoo':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/iamjamestl/portage-gentoo.git',
    force    => true,
    depth    => 1,
  }

  vcsrepo { '/var/cache/portage/nest':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/iamjamestl/portage-overlay.git',
    force    => true,
    depth    => 1,
  }

  vcsrepo { '/var/cache/portage/haskell':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/iamjamestl/gentoo-haskell.git',
    force    => true,
    depth    => 1,
  }
}
