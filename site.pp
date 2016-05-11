Service {
  provider => systemd,
}

Firewall {
  noop => str2bool("$::chroot")
}

Firewallchain {
  noop => str2bool("$::chroot")
}

hiera_include('classes')
