class nest::base::cli {
  nest::lib::package { 'app-admin/nest-cli':
    # Immutable capacity/transaction source; retain the activation-safe rollback floor.
    ensure => '0.9.0_p20261021-r2',
    tag    => 'nest_cli_package',
  }

  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root',
    ;

    '/etc/nest':
      ensure => directory,
    ;

    '/etc/nest/reset-filter.rules':
      content => epp('nest/cli/reset-filter.rules.epp', { 'rules' => $nest::reset_filter_rules }),
      tag     => 'dns_failover',
    ;

    '/etc/nest/reset-test-filter.rules':
      source => 'puppet:///modules/nest/cli/reset-test-filter.rules',
    ;
  }
}
