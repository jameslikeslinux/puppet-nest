class nest::base::firmware::crust {
  # For nest::base::portage::makeopts
  include '::nest::base::portage'

  nest::lib::toolchain { 'or1k-linux-musl':
    gcc_only => true,
  }

  vcsrepo { '/usr/src/crust':
    ensure   => latest,
    provider => git,
    source   => 'https://gitlab.james.tl/nest/forks/crust.git',
    revision => 'main',
  }
  ~>
  exec { '/bin/rm -rf /usr/src/crust/.config':
    refreshonly => true,
  }

  $defconfig = $facts['profile']['platform'] ? {
    'sopine' => 'pine64_plus_defconfig',
  }

  exec { 'crust-defconfig':
    command => "/usr/bin/make ${defconfig}",
    cwd     => '/usr/src/crust',
    creates => '/usr/src/crust/.config',
    require => Vcsrepo['/usr/src/crust'],
  }
  ~>
  exec { 'crust-build':
    command     => "/usr/bin/make ${::nest::base::portage::makeopts} ${build_options}",
    cwd         => '/usr/src/crust',
    path        => ['/usr/lib/distcc/bin', '/usr/bin', '/bin'],
    environment => 'HOME=/root',  # for distcc
    timeout     => 0,
    # just attempt once per config change
    refreshonly => true,
    noop        => !$facts['build'],
    require     => Nest::Lib::Toolchain['or1k-linux-musl'],
  }
}
