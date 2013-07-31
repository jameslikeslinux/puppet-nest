class ssh::server (
    $port          = 22,
    $x11forwarding = true,
) {
    file { '/etc/ssh/sshd_config':
        mode    => '0600',
        owner   => 'root',
        group   => 'root',
        content => template('ssh/sshd_config.erb'),
        require => Class['ssh'],
        notify  => Openrc::Service['sshd'],
    }

    openrc::service { 'sshd':
        enable => true,
    }
}
