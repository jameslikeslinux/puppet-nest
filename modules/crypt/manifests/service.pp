class crypt::service {
    openrc::service { 'dmcrypt':
        runlevel => 'boot',
        enable   => true,
        require  => Concat['/etc/conf.d/dmcrypt'],
    }
}
