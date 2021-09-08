if $trusted['certname'] in ['bolt', 'puppetdb'] {
  fail("${trusted['certname']} is not allowed to use Puppet")
}

case $facts['osfamily'] {
  'Gentoo': {
    # Effectively disable service resources in containers
    if $facts['is_container'] {
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
