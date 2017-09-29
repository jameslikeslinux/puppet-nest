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
    require => File['/etc/portage/patches/www-client/chromium/chromium-enable-scaled-font-hinting.patch'],
  }

  file { '/etc/chromium/scaling':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "CHROMIUM_FLAGS=\"\${CHROMIUM_FLAGS} --force-device-scale-factor=${::nest::text_scaling_factor} --enable-use-zoom-for-dsf\"\n",
    require => Package['www-client/chromium'],
  }
}
