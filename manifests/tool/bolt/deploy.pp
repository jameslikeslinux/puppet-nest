# Credentials for trusted OpenVox code-deployment consumers, not a server.
class nest::tool::bolt::deploy {
  require nest::tool::bolt
  tag 'nest::tool::bolt'

  # Shared with the OpenVox r10k sidecars; keep the existing encrypted authority.
  $deploy_key = lookup('nest::service::puppet::r10k_deploy_key', Sensitive)

  file { '/etc/puppetlabs/bolt/deploy-key.pem':
    ensure    => file,
    mode      => '0600',
    owner     => 'root',
    group     => 'root',
    content   => $deploy_key,
    show_diff => false,
  }
}
