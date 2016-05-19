class nest::profile::workstation::chromium {
  nest::portage::package_use { 'www-client/chromium':
    use => 'widevine',
  }

  package { [
    'www-client/chromium',
    'www-plugins/chrome-binary-plugins'
  ]:
    ensure => installed,
  }

  file { '/etc/chromium/scaling':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "CHROMIUM_FLAGS=\"\${CHROMIUM_FLAGS} --force-device-scale-factor=${::nest::scaling_factor}\"\n",
    require => Package['www-client/chromium'],
  }
}
