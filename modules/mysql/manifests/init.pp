class mysql (
    $password
) {
    portage::package { 'dev-db/mysql':
        ensure => installed,
    }

    file { '/root/.my.cnf':
        mode    => '0600',
        owner   => 'root',
        group   => 'root',
        content => template('mysql/root-my.cnf.erb'),
    }

    exec { 'config-mysql':
        command => '/usr/bin/emerge --config dev-db/mysql',
        creates => '/var/lib/mysql/mysql',
        require => [
            Portage::Package['dev-db/mysql'],
            File['/root/.my.cnf'],
        ],
    }

    openrc::service { 'mysql': 
        enable  => true,
        require => Exec['config-mysql'],
    }
}
