class nest::profile::setup::portage {
  class { 'portage':
    eselect_ensure => installed,
  }

  portage::makeconf { 'accept_license':
    content => '*',
  }

  portage::makeconf { 'cflags':
    content => $portage_cflags,
  }

  portage::makeconf { 'cxxflags':
    content => $portage_cxxflags,
  }

  portage::makeconf { 'cpu_flags_x86':
    content => $portage_cpu_flags_x86,
  }

  portage::makeconf { 'features':
    content => 'buildpkg splitdebug'
  }

  $makejobs_by_memory = ceiling($memory['system']['total_bytes'] / (512.0 * 1024 * 1024))
  $makejobs_non_distcc = $processorcount + 1

  $makejobs_non_distcc_min = ($makejobs_by_memory < $makejobs_non_distcc) ? {
    true    => $makejobs_by_memory,
    default => $makejobs_non_distcc,
  } 

  $loadlimit = $::processorcount + 1

  portage::makeconf { 'makeopts':
    content => "-j${makejobs_non_distcc_min} -l${loadlimit}",
  }

  eselect { 'profile':
    set     => $::nest::gentoo_profile,
    require => Class['portage'],
  }

  exec { 'emerge-update-world':
    command     => '/usr/bin/emerge -DuN @world',
    timeout     => 0,
    refreshonly => true,
    subscribe   => Eselect['profile'],

    # XXX: Workaround circular dependency between:
    #   dev-util/cmake[qt5]
    #   media-libs/harfbuzz[graphite]
    # Remove this when Gentoo fixes the problem.
    environment => 'USE=-graphite',
  }

  $::nest::package_keywords.each |$target, $package_keywords| {
    $defaults = { target => $target, before => Exec['emerge-newuse-world'] }
    create_resources(package_keywords, $package_keywords, $defaults)
  }

  $::nest::package_use.each |$target, $package_use| {
    $defaults = { target => $target, notify => Exec['emerge-newuse-world'] }
    create_resources(package_use, $package_use, $defaults)
  }

  exec { 'emerge-newuse-world':
    command     => '/usr/bin/emerge -DN @world',
    timeout     => 0,
    refreshonly => true,
  }
}
