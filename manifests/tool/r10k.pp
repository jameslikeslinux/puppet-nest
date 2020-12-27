class nest::tool::r10k {
  package_accept_keywords { 'dev-libs/libgit2':
    version => '~1.1.0',
  }
  ->
  package { 'libgit2':
    ensure => installed,
  }
  ->
  package { 'rugged':
    ensure          => installed,
    install_options => ['--use-system-libraries'],
    provider        => gem,
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
  package { 'r10k':
    ensure => installed,
  }
}
