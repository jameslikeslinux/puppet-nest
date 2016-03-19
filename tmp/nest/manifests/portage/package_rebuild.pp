define nest::portage::package_rebuild {
  # See: https://github.com/gentoo/puppet-portage/blob/master/manifests/package.pp#L225
  exec { "rebuild_${name}":
    command     => "emerge --changed-use -u1 ${name}",
    refreshonly => true,
    timeout     => 43200,
    path        => ['/usr/local/sbin','/usr/local/bin',
                    '/usr/sbin','/usr/bin','/sbin','/bin'],
  }
}
