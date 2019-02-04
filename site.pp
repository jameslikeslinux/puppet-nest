Service {
  provider => systemd,
}

Firewall {
  noop => str2bool("$::chroot")
}

Firewallchain {
  noop => str2bool("$::chroot")
}

if $facts['osfamily'] == 'windows' {
  stage { 'first':
    before => Stage['main'],
  }

  class { [
    'chocolatey',
    'cygwin'
  ]:
    stage => 'first',
  }

  Package {
    provider => 'chocolatey',
  }
}

hiera_include('classes')
