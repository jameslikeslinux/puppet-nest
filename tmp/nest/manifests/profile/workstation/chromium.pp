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

  file { '/etc/portage/patches/www-client/chromium/chromium-enable-scaled-font-hinting.patch':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/chromium/chromium-enable-scaled-font-hinting.patch',
  }

  # Related to: https://bugs.chromium.org/p/skia/issues/detail?id=6931
  file { '/etc/portage/patches/www-client/chromium/chromium-skia-allow-full-hinting-with-subpixel-positioning.patch':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/chromium/chromium-skia-allow-full-hinting-with-subpixel-positioning.patch',
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
    require => [
      File['/etc/portage/patches/www-client/chromium/chromium-enable-scaled-font-hinting.patch'],
      File['/etc/portage/patches/www-client/chromium/chromium-skia-allow-full-hinting-with-subpixel-positioning.patch'],
    ],
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
