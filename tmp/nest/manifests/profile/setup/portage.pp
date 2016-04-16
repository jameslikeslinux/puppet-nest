class nest::profile::setup::portage {
  class { '::portage':
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

  $use = $::nest::use ? {
    undef   => '',
    default => join(sort($::nest::use), ' '),
  }

  $use_ensure = $::nest::use ? {
    undef   => absent,
    default => undef,
  }

  portage::makeconf { 'use':
    content => join(sort($::nest::use), ' '),
    ensure  => $use_ensure,
    notify  => Exec['emerge-newuse-world'],
  }

  $makejobs_by_memory = ceiling($memory['system']['total_bytes'] / (512.0 * 1024 * 1024))
  $makejobs_non_distcc = $processorcount + 1

  $makejobs_non_distcc_min = ($makejobs_by_memory < $makejobs_non_distcc) ? {
    true    => $makejobs_by_memory,
    default => $makejobs_non_distcc,
  } 

  $loadlimit = $::processorcount + 1
  $makeopts = "-j${makejobs_non_distcc_min} -l${loadlimit}"

  portage::makeconf { 'makeopts':
    content => $makeopts,
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

    # XXX: Workaround circular dependency between:
    #   dev-util/cmake[qt5]
    #   media-libs/harfbuzz[graphite]
    # Remove this when Gentoo fixes the problem.
    environment => 'USE=-graphite',
  }


  # Create portage package properties from Hiera and find all of the
  # ones defined throughout the Puppet catalog, and make them come
  # before or trigger a package rebuild for the new settings to
  # take effect.

  create_resources(package_keywords, $::nest::package_keywords)
  Package_keywords <| |> {
    before => Exec['emerge-newuse-world']
  }

  create_resources(package_use, $::nest::package_use)
  Package_use <| |> {
    notify => Exec['emerge-newuse-world'],
  }

  exec { 'emerge-newuse-world':
    command     => '/usr/bin/emerge -DN @world',
    timeout     => 0,
    refreshonly => true,
    require     => Class['::portage'],
  }
}
