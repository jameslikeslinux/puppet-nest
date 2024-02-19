class nest::base::branding {
  tag 'configure_profile'

  $variant = $facts['profile']['role'] ? {
    'server'      => 'Server',
    'workstation' => 'Workstation',
    default       => fail("Unhandled role ${facts['profile']['role']}"),
  }

  $image_id = $facts['build'] ? {
    /^stage/ => $facts['build'],
    default  => $facts['release']['image_id'],
  }

  $os_release_content = epp('nest/branding/os-release.epp', {
    variant    => $variant,
    variant_id => $facts['profile']['role'],
    build_id   => pick_default($facts['ci_job_id'], $facts['release']['build_id']),
    image_id   => $image_id,
  })

  file { '/etc/os-release':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $os_release_content,
  }

  # For os.distro facts
  nest::lib::package { 'sys-apps/lsb-release':
    ensure => installed,
  }
}
