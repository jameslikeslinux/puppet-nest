class profile::role::puppet_dashboard {
    class { 'private::profile::role::puppet_dashboard': }

    class { 'puppet::dashboard':
        target       => '/app/dashboard',
        db_password  => $private::profile::role::puppet_dashboard::db_password,
        secret_token => $private::profile::role::puppet_dashboard::secret_token,
    }
}
