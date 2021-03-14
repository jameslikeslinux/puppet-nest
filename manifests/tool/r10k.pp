class nest::tool::r10k {
  package_accept_keywords { 'dev-libs/libgit2':
    version => '~1.1.0',
  }
  ->
  package { 'dev-libs/libgit2':
    ensure => installed,
  }
  ->
  exec { 'gem-install-rugged':
    command => '/usr/bin/gem install rugged -- --use-system-libraries',
    unless  => '/usr/bin/gem which rugged',
  }
  ->
  package { 'rugged':
    ensure   => installed,
    provider => gem,
  }

  package_accept_keywords { [
    'app-admin/r10k',
    'dev-ruby/colored',
    'dev-ruby/colored2',
    'dev-ruby/cri',
    'dev-ruby/faraday',
    'dev-ruby/faraday_middleware',
    'dev-ruby/hashie',
    'dev-ruby/minitar',
    'dev-ruby/multipart-post',
    'dev-ruby/puppet_forge',
    'dev-ruby/rash_alt',
    'dev-ruby/simple_oauth',
  ]: }
  ->
  package { 'app-admin/r10k':
    ensure => installed,
  }
}
