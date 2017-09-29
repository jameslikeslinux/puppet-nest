class nest::profile::workstation::chromium {
  file { [
    '/etc/portage/patches/www-client',
    '/etc/portage/patches/www-client/chromium',
  ]:
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  $patches = [
    'chromium-disable-scaling-factor-blacklist.patch',
    'chromium-enable-scaled-font-hinting.patch',

    # Related to: https://bugs.chromium.org/p/skia/issues/detail?id=6931
    'chromium-skia-allow-full-hinting-with-subpixel-positioning.patch',
  ]

  $patches.each |$patch| {
    file { "/etc/portage/patches/www-client/chromium/${patch}":
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      source => "puppet:///modules/nest/chromium/${patch}",
      before => Package['www-client/chromium'],
    }
  }

  nest::portage::package_use { 'www-client/chromium':
    use => 'widevine',
  }

  package_env { 'www-client/chromium':
    env    => 'no-debug.conf',
    before => Package['www-client/chromium'],
  }

  package { [
    'www-client/chromium',
    'www-plugins/chrome-binary-plugins'
  ]:
    ensure  => installed,
  }

  file { '/etc/chromium/scaling':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "CHROMIUM_FLAGS=\"\${CHROMIUM_FLAGS} --force-device-scale-factor=${::nest::text_scaling_factor} --enable-use-zoom-for-dsf\"\n",
    require => Package['www-client/chromium'],
  }

  file { '/etc/chromium/scrolling':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "CHROMIUM_FLAGS=\"\${CHROMIUM_FLAGS} --disable-smooth-scrolling\"\n",
    require => Package['www-client/chromium'],
  }
}
