class nest::node::puppet (
  String[1] $r10k_deploy_key,
) {
  package { 'libgit2':
    ensure => installed,
  }

  package { 'rugged':
    ensure          => installed,
    install_options => ['--use-system-libraries'],
    provider        => gem,
    require         => Package['libgit2'],
  }

  package { 'r10k':
    ensure => installed,
  }

  file {
    default:
      owner  => 'root',
      group  => 'root',
    ;

    '/etc/puppetlabs/r10k':
      mode   => '0755',
      ensure => directory,
    ;

    '/etc/puppetlabs/r10k/r10k.yaml':
      mode   => '0644',
      source => 'puppet:///modules/nest/puppet/r10k.yaml',
    ;

    '/etc/puppetlabs/r10k/id_rsa':
      mode    => '0600',
      content => $r10k_deploy_key,
    ;
  }

  file { '/etc/eyaml':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  $eyaml_config = @(EOT)
    ---
    pkcs7_private_key: '/srv/puppetserver/ssl/ca/ca_key.pem'
    pkcs7_public_key: '/srv/puppetserver/ssl/certs/ca.pem'
    | EOT

  file { '/etc/eyaml/config.yaml':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $eyaml_config,
  }
}
