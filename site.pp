Service {
  provider => systemd,
}

stage { 'pre': } -> Stage['main']

class { 'nest':
  stage => 'pre',
}

hiera_include('classes')
