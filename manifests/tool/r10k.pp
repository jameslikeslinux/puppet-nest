class nest::tool::r10k {
  package_accept_keywords { [
    'app-admin/r10k',
    'dev-ruby/colored',
    'dev-ruby/colored2',
    'dev-ruby/cri',
    'dev-ruby/faraday',
    'dev-ruby/faraday-net_http',
    'dev-ruby/faraday_middleware',
    'dev-ruby/hashie',
    'dev-ruby/jwt',
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

  file_line { 'ssh_config-r10k_key':
    path => '/etc/ssh/ssh_config',
    line => 'IdentityFile /etc/puppetlabs/r10k/id_rsa',
  }

  # Collect trusted GitLab host keys
  Sshkey <<| tag == 'gitlab' |>>
}
