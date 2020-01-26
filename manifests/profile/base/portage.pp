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

  $makejobs_by_memory = ceiling($facts['memory']['system']['total_bytes'] / (512.0 * 1024 * 1024))
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

  # Mesa has circular dependencies when USE=vaapi is set, so just build it
  # before any USE variables are set and it will eventually converge.
  if $nest and $::nest['profile'] == 'workstation' {
    exec { '/usr/bin/emerge --oneshot media-libs/mesa':
      timeout     => 0,
      refreshonly => true,
      subscribe   => Eselect['profile'],
      before      => Portage::Makeconf['use'],
    }
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
      content => ['buildpkg', 'distcc', 'splitdebug'];
    'input_devices':
      ensure  => $input_devices_ensure,
      content => $::nest::input_devices;
    'makeopts':
      content => $makeopts;
    'pkgdir':
      content => "/nest/portage/packages/${::architecture}-${::nest['profile']}";
    'use':
      ensure  => $use_ensure,
      content => $::nest::use_combined;
    'video_cards':
      ensure  => $video_cards_ensure,
      content => $::nest::video_cards;
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
  create_resources(package_mask, $::nest::package_mask_hiera, { 'before' => Class['::portage'] })
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

  file { '/etc/portage/package.keywords/nest':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "*/*::nest ~amd64\n",
  }

  file { '/etc/portage/package.keywords/tlp':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "*/*::tlp ~amd64\n",
  }

  file { [
    '/etc/portage/patches',
    '/etc/portage/patches/x11-drivers',
    '/etc/portage/patches/x11-drivers/xf86-input-libinput',
    '/etc/portage/profile'
  ]:
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  file { '/etc/portage/patches/x11-drivers/xf86-input-libinput/dpiscalefactor-workaround.patch':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/xorg/libinput-dpiscalefactor-workaround.patch',
  }

  # Enable libzfs USE flag for GRUB
  # XXX: This could be made more generic if needed
  $use_mask_content = @(EOT)
    -input_devices_libinput
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

    [tlp]
    location = /var/cache/portage/tlp
    sync-type = git
    sync-uri = https://github.com/iamjamestl/tlp-portage.git
    auto-sync = yes
    masters = gentoo
    | EOT

  file { '/etc/portage/repos.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $repos_conf,
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
      source => 'https://github.com/iamjamestl/gentoo-haskell.git',
    ;

    '/var/cache/portage/tlp':
      source => 'https://github.com/iamjamestl/tlp-portage.git',
    ;
  }

  exec { '/usr/bin/eix-update':
    refreshonly => true,
  }
}
