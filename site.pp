unless defined('$role') {
  $role = $facts['osfamily'] ? {
    'windows' => 'workstation',
    default   => 'server',
  }
}

unless defined('$profile') {
  $profile = 'generic'
}


case $facts['osfamily'] {
  'Gentoo': {
    $is_container = $facts['virtual'] == 'lxc'

    Service {
      provider => systemd,
    }

    Firewall {
      noop => $is_container,
    }

    Firewallchain {
      noop => $is_container,
    }

    Sysctl {
      noop => $is_container,
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
