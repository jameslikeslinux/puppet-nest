case $facts['osfamily'] {
  'Gentoo': {
    Service {
      provider => systemd,
    }

    Firewall {
      noop => str2bool("$::chroot")
    }

    Firewallchain {
      noop => str2bool("$::chroot")
    }
  }

  'windows': {
    Concat {
      # The default is usually 0644, but Windows keeps changing it to 0674, so
      # just accept what it does.
      mode => '0674',
    }

    stage { 'first':
      before => Stage['main'],
    }

    class { 'chocolatey':
      stage => 'first',
    }

    Package {
      provider => 'chocolatey',
    }
  }
}

hiera_include('classes')
