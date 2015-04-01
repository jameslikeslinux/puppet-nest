class nest::role::terminal_client {
    portage::package { 'net-dialup/minicom':
        ensure => installed,
    }
}
