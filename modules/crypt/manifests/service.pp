class crypt::service {
    openrc::service { 'dmcrypt':
        runlevel => 'boot',
        enable   => false,
        require  => Concat['/etc/conf.d/dmcrypt'],
    }

    file { '/etc/local.d/dmcrypt.stop':
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/crypt/dmcrypt.stop',
    }
}
