class nest::base::fstab {
  $hostname = regsubst($::trusted['certname'], '\..*', '')

  if $facts['live'] {
    $fscache = false
    Mount <| tag == 'live' |>
  } elsif $::platform == 'beagleboneblack' {
    $fscache = false
    Mount <| tag == 'beagleboneblack' |>
  } elsif $::platform == 'pinebookpro' {
    Mount <| tag == 'pinebookpro' |>
  } elsif $::nest::nestfs_hostname == "${hostname}.nest" {
    Mount <| tag == 'nestfs-host' |>
  } elsif $::nest::bootloader == 'systemd' {
    Mount <| tag == 'systemd-boot' |>
  } else {
    Mount <| tag == 'default' |>
  }

  $boot_fstype = $::nest::bootloader ? {
    'systemd' => 'vfat',
    default   => 'ext2',
  }

  $nest_options = $fscache ? {
    false   => 'noauto,x-systemd.automount,x-systemd.requires=openvpn-client@nest.service',
    default => 'noauto,fsc,x-systemd.automount,x-systemd.requires=openvpn-client@nest.service,x-systemd.requires=cachefilesd.service',
  }

  @mount {
    '/boot':
      device  => "PARTLABEL=${hostname}-boot",
      fstype  => $boot_fstype,
      options => 'defaults',
      pass    => 2,
      tag     => ['beagleboneblack', 'pinebookpro', 'nestfs-host', 'systemd-boot', 'default'],
    ;

    '/efi':
      device  => "PARTLABEL=${hostname}-efi",
      fstype  => 'vfat',
      options => 'defaults',
      pass    => 2,
      tag     => ['nestfs-host', 'systemd-boot'],
    ;

    'swap':
      name    => 'none',
      device  => "LABEL=${hostname}-swap",
      fstype  => 'swap',
      options => 'discard',
      tag     => ['beagleboneblack', 'pinebookpro', 'nestfs-host', 'systemd-boot', 'default'],
    ;

    '/var':
      device  => 'none',
      fstype  => 'none',
      options => 'fake,x-systemd.requires=zfs-mount.service',
      tag     => ['beagleboneblack', 'pinebookpro', 'nestfs-host', 'systemd-boot', 'default'],
    ;

    '/var/cache/fscache':
      device  => "LABEL=${hostname}-fscache",
      fstype  => 'ext4',
      options => 'defaults,discard',
      pass    => 2,
      tag     => ['pinebookpro', 'systemd-boot', 'default'],
    ;

    '/nest':
      name    => '/nest',
      device  => "${::nest::nestfs_hostname}:/nest",
      fstype  => 'nfs',
      options => $nest_options,
      tag     => ['live', 'beagleboneblack', 'pinebookpro', 'systemd-boot', 'default'],
    ;
  }

  resources { 'mount':
    purge => true,
  }

  # XXX: Hide harmless error at shutdown when trying to unmount /var due to
  # journald still writing to /var/log/journal
  # See: https://github.com/systemd/systemd/issues/867
  $var_lazy_unmount = @(END_OVERRIDE)
    [Mount]
    LazyUnmount=yes
    | END_OVERRIDE

  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root',
    ;

    '/etc/systemd/system/var.mount.d':
      ensure => directory,
    ;

    '/etc/systemd/system/var.mount.d/lazyunmount.conf':
      content => $var_lazy_unmount,
      notify  => Nest::Lib::Systemd_reload['fstab'],
    ;
  }

  ::nest::lib::systemd_reload { 'fstab': }
}
