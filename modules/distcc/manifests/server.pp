class distcc::server {
    include distcc

    file { '/etc/conf.d/distccd':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/distcc/distccd.confd',
        require => Class['distcc'],
    }

    openrc::service { 'distccd':
        enable  => true,
        require => File['/etc/conf.d/distccd'],
    }
}
