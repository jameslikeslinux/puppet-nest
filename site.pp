case $facts['osfamily'] {
  'Gentoo': {
    # Effectively disable firewall and service resources in containers
    if $facts['is_container'] {
      Firewall <||> {
        ensure => absent,
      }

      Firewallchain <||> {
        ensure => absent,
      }

      # Built-in chains have to be handled specially
      Firewallchain <| policy != undef |> {
        ensure => present,
        policy => accept,
      }

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
