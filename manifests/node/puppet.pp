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
}
