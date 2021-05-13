class nest::tool::bitwarden_cli {
  include 'nodejs'

  package { '@bitwarden/cli':
    ensure   => installed,
    provider => npm,
  }
}
