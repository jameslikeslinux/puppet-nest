unless defined('$platform') {
  if $facts['profile'] {
    $platform = $facts['profile']['platform']
  } else {
    $platform = $facts['hardwaremodel']
  }
}

unless defined('$role') {
  if $facts['profile'] {
    $role = $facts['profile']['role']
  } elsif $facts['osfamily'] == 'windows' {
    $role = 'workstation'
  } else {
    $role = 'server'
  }
}

case $facts['osfamily'] {
  'Gentoo': {
    $is_container = $facts['virtual'] == 'lxc' or $facts['build']

    Firewall {
      noop => $is_container,
    }

    Firewallchain {
      noop => $is_container,
    }

    Sysctl {
      noop => $is_container,
    }

    Service {
      provider => systemd,
    }

    if $is_container {
      Service <||> {
        ensure => undef,
      }
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
