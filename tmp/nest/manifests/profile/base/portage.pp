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
  $makejobs_non_distcc = $processorcount + 1

  $makejobs_non_distcc_min = ($makejobs_by_memory < $makejobs_non_distcc) ? {
    true    => $makejobs_by_memory,
    default => $makejobs_non_distcc,
  } 

  $loadlimit = $::processorcount + 1
  $makeopts = "-j${makejobs_non_distcc_min} -l${loadlimit}"


  class { '::portage':
    eselect_ensure => installed,
  }
  
  portage::makeconf {
    'accept_license':
      content => '*';
    'cflags':
      content => $portage_cflags;
    'cxxflags':
      content => $portage_cxxflags;
    'cpu_flags_x86':
      content => $portage_cpu_flags_x86;
    'distdir':
      content => '/nest/portage/distfiles';
    'emerge_default_opts':
      content => '${EMERGE_DEFAULT_OPTS} --usepkg';
    'features':
      content => ['buildpkg', 'splitdebug'];
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

  eselect { 'profile':
    set     => $::nest::gentoo_profile,
    require => Class['::portage'],
  }

  exec { 'emerge-update-world':
    command     => '/usr/bin/emerge -DuN @world',
    timeout     => 0,
    refreshonly => true,
    subscribe   => Eselect['profile'],
  }

  # Create portage package properties rebuild affected packages
  create_resources(package_keywords, $::nest::package_keywords_hiera, { 'before' => Class['::portage'] })
  create_resources(package_use, $::nest::package_use_hiera, { 'notify' => Class['::portage'] })

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

  # Enable libzfs USE flag for GRUB
  # XXX: This could be made more generic if needed
  file { '/etc/portage/profile':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

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

    [overlay]
    location = /var/cache/portage/overlay
    sync-type = git
    sync-uri = https://github.com/iamjamestl/portage-overlay.git
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

  vcsrepo { '/var/cache/portage/overlay':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/iamjamestl/portage-overlay.git',
    force    => true,
    depth    => 1,
  }
}
