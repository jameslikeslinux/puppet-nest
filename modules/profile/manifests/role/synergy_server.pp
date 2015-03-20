class profile::role::synergy_server {
    class { 'synergy::server': }

    file { '/etc/synergy.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => "puppet:///modules/profile/role/synergy_server/${clientcert}.conf",
        require => Class['synergy::server'],
    }
}
