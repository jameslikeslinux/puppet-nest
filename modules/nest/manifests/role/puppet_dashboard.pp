class nest::role::puppet_dashboard {
    class { 'private::nest::role::puppet_dashboard': }

    class { 'puppet::dashboard':
        target       => '/app/dashboard',
        db_password  => $private::nest::role::puppet_dashboard::db_password,
        secret_token => $private::nest::role::puppet_dashboard::secret_token,
    }
}
