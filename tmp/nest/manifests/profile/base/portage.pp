class nest::profile::base::portage {
  if is_string($::nest::package_server) {
    $binhost_ensure = undef
    $package_features = 'getbinpkg'
  } else {
    $binhost_ensure = absent
    $package_features = 'buildpkg'
  }

  $features = [
    'splitdebug',
    $package_features,
  ]

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
    'features':
      content => sort(flatten($features));
    'input_devices':
      content => $::nest::input_devices,
      ensure  => $input_devices_ensure;
    'makeopts':
      content => $makeopts;
    'portage_binhost':
      content => "http://${::nest::package_server}/packages",
      ensure  => $binhost_ensure;
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
  create_resources(package_keywords, $::nest::package_keywords, { 'before' => Class['::portage'] })
  create_resources(package_use, $::nest::package_use, { 'notify' => Class['::portage'] })

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
}
